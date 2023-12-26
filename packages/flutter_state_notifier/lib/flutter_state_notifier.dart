library flutter_state_notifier;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
// ignore: undefined_hidden_name
import 'package:provider/provider.dart' hide Locator;
import 'package:provider/single_child_widget.dart';
import 'package:state_notifier/state_notifier.dart';

export 'package:state_notifier/state_notifier.dart' hide Listener, Locator;

/// {@template flutter_state_notifier.state_notifier_builder}
/// Listens to a [StateNotifier] and use it builds a widget tree based on the
/// latest value.
///
/// This is similar to [ValueListenableBuilder] for [ValueNotifier].
/// {@endtemplate}
class StateNotifierBuilder<T> extends StatefulWidget {
  /// {@macro flutter_state_notifier.state_notifier_builder}
  const StateNotifierBuilder({
    Key? key,
    required this.builder,
    required this.stateNotifier,
    this.child,
  }) : super(key: key);

  /// A callback that builds a [Widget] based on the current value of [stateNotifier]
  ///
  /// Cannot be `null`.
  final ValueWidgetBuilder<T> builder;

  /// The listened to [StateNotifier].
  ///
  /// Cannot be `null`.
  final StateNotifier<T> stateNotifier;

  /// A cache of a subtree that does not depend on [stateNotifier].
  ///
  /// It will be sent untouched to [builder]. This is useful for performance
  /// optimizations to not rebuild the entire widget tree if it isn't needed.
  final Widget? child;

  @override
  _StateNotifierBuilderState<T> createState() =>
      _StateNotifierBuilderState<T>();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(
        DiagnosticsProperty<StateNotifier<T>>('stateNotifier', stateNotifier),
      )
      ..add(DiagnosticsProperty<Widget>('child', child))
      ..add(ObjectFlagProperty<ValueWidgetBuilder<T>>.has('builder', builder));
  }
}

class _StateNotifierBuilderState<T> extends State<StateNotifierBuilder<T>> {
  late T state;
  VoidCallback? removeListener;

  @override
  void initState() {
    super.initState();
    _listen(widget.stateNotifier);
  }

  @override
  void didUpdateWidget(StateNotifierBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.stateNotifier != oldWidget.stateNotifier) {
      _listen(widget.stateNotifier);
    }
  }

  void _listen(StateNotifier<T> notifier) {
    removeListener?.call();
    removeListener = notifier.addListener(_listener);
  }

  void _listener(T value) {
    setState(() => state = value);
  }

  @override
  void dispose() {
    removeListener?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, state, widget.child);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<T>('state', state));
  }
}

// Don't uses a closure to not capture local variables.
Locator _contextToLocator(BuildContext context) {
  return <T>() {
    try {
      return Provider.of<T>(context, listen: false);
    } on ProviderNotFoundException catch (_) {
      throw DependencyNotFoundException<T>();
    }
  };
}

/// A provider for [StateNotifier], which exposes both the controller and its
/// [StateNotifier.state].
///
/// It can be used like most providers.
///
/// Consider the following [StateNotifier]:
/// ```dart
/// class MyController extends StateNotifier<MyValue> {
/// ...
/// }
/// ```
///
/// Then we can expose it to a Flutter app by doing:
///
/// ```dart
/// MultiProvider(
///   providers: [
///     StateNotifierProvider<MyController, MyValue>(create: (_) => MyController()),
///   ],
/// )
/// ```
///
/// This will allow both:
///
/// - `context.watch<MyController>()`
/// - `context.watch<MyValue>()`
///
/// Note that watching `MyController` will not cause the listener to rebuild when
/// [StateNotifier.state] updates.
abstract class StateNotifierProvider<Controller extends StateNotifier<Value>,
        Value>
    implements
        // ignore: avoid_implementing_value_types
        SingleChildStatelessWidget {
  /// Creates a [StateNotifier] instance and exposes both the [StateNotifier]
  /// and its [StateNotifier.state] using `provider`.
  ///
  /// **DON'T** use this with an existing [StateNotifier] instance, as removing
  /// the provider from the widget tree will dispose the [StateNotifier].\
  /// Instead consider using [StateNotifierBuilder].
  ///
  /// `create` cannot be `null`.
  factory StateNotifierProvider({
    Key? key,
    required Create<Controller> create,
    bool? lazy,
    TransitionBuilder? builder,
    Widget? child,
  }) = _StateNotifierProvider<Controller, Value>;

  /// Exposes an existing [StateNotifier] and its [value].
  ///
  /// This will not call [StateNotifier.dispose] when the provider is removed
  /// from the widget tree.
  ///
  /// It will also not setup [LocatorMixin].
  ///
  /// `value` cannot be `null`.
  factory StateNotifierProvider.value({
    Key? key,
    required Controller value,
    TransitionBuilder? builder,
    Widget? child,
  }) = _StateNotifierProviderValue<Controller, Value>;
}

class _StateNotifierProviderValue<Controller extends StateNotifier<Value>,
        Value> extends SingleChildStatelessWidget
    implements StateNotifierProvider<Controller, Value> {
  // ignore: prefer_const_constructors_in_immutables
  _StateNotifierProviderValue({
    Key? key,
    required this.value,
    this.builder,
    Widget? child,
  }) : super(key: key, child: child);

  final Controller value;
  final TransitionBuilder? builder;

  @override
  Widget buildWithChild(BuildContext context, Widget? child) {
    return InheritedProvider.value(
      value: value,
      child: StateNotifierBuilder<Value>(
        stateNotifier: value,
        builder: (c, state, _) {
          return Provider.value(
            value: state,
            child: builder != null //
                ? Builder(builder: (c) => builder!(c, child))
                : child,
          );
        },
      ),
    );
  }

  @override
  SingleChildStatelessElement createElement() {
    return _StateNotifierProviderElement(this);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty('controller', value));
  }
}

class _StateNotifierProvider<Controller extends StateNotifier<Value>, Value>
    extends SingleChildStatelessWidget
    implements StateNotifierProvider<Controller, Value> {
  // ignore: prefer_const_constructors_in_immutables
  _StateNotifierProvider({
    Key? key,
    required this.create,
    this.lazy,
    this.builder,
    Widget? child,
  }) : super(key: key, child: child);

  final Create<Controller> create;
  final bool? lazy;
  final TransitionBuilder? builder;

  @override
  Widget buildWithChild(BuildContext context, Widget? child) {
    return InheritedProvider<Controller>(
      create: (context) {
        final result = create(context);
        assert(
          result.onError == null,
          'StateNotifierProvider created a StateNotifier that was already passed'
          ' to another StateNotifierProvider',
        );
        // ignore: avoid_types_on_closure_parameters
        result.onError = (Object error, StackTrace? stack) {
          FlutterError.reportError(FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'flutter_state_notifier',
          ));
        };
        if (result is LocatorMixin) {
          (result as LocatorMixin)
            ..read = _contextToLocator(context)
            // ignore: invalid_use_of_protected_member
            ..initState();
        }
        return result;
      },
      debugCheckInvalidValueType: kReleaseMode
          ? null
          : (value) {
              assert(
                !value.hasListeners,
                'StateNotifierProvider created a StateNotifier that is already'
                ' being listened to by something else',
              );
            },
      update: (context, controller) {
        if (controller is LocatorMixin) {
          // ignore: cast_nullable_to_non_nullable
          final locatorMixin = controller as LocatorMixin;
          late Locator debugPreviousLocator;
          assert(() {
            // ignore: invalid_use_of_protected_member
            debugPreviousLocator = locatorMixin.read;
            locatorMixin.read = <T>() {
              throw StateError("Can't use `read` inside the body of `update");
            };
            return true;
          }(), '');
          // ignore: invalid_use_of_protected_member
          locatorMixin.update(<T>() => Provider.of<T>(context));
          assert(() {
            locatorMixin.read = debugPreviousLocator;
            return true;
          }(), '');
        }
        return controller!;
      },
      dispose: (_, controller) => controller.dispose(),
      child: DeferredInheritedProvider<Controller, Value>(
        lazy: lazy,
        create: (context) {
          return Provider.of<Controller>(context, listen: false);
        },
        startListening: (context, setState, controller, _) {
          return controller.addListener(setState);
        },
        child: builder != null //
            ? Builder(builder: (c) => builder!(c, child))
            : child,
      ),
    );
  }

  @override
  SingleChildStatelessElement createElement() {
    return _StateNotifierProviderElement(this);
  }
}

class _StateNotifierProviderElement<Controller extends StateNotifier<Value>,
    Value> extends SingleChildStatelessElement {
  _StateNotifierProviderElement(StateNotifierProvider<Controller, Value> widget)
      : super(widget);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    late Element provider;

    void visitor(Element e) {
      if (e.widget is InheritedProvider<Value>) {
        provider = e;
      } else {
        e.visitChildren(visitor);
      }
    }

    visitChildren(visitor);

    provider.debugFillProperties(properties);
  }
}

/// Signature for the `listener` function which takes the `BuildContext` along
/// with the `state` and is responsible for executing in response to
/// `state` changes.
typedef StateNotifierWidgetListener<ValueT> = void Function(
    BuildContext context, ValueT state);

/// Signature for the `listenWhen` function which takes the previous `state`
/// and the current `state` and is responsible for returning a [bool] which
/// determines whether or not to call [StateNotifierWidgetListener] of
/// [StateNotifierListener] with the current `state`.
typedef StateNotifierListenerCondition<ValueT> = bool Function(
    ValueT previous, ValueT current);

/// {@template state_notifier_listener}
/// A widget that takes a [StateNotifierWidgetListener] and a [stateNotifier]
/// and invokes the [listener] in response to `state` changes in the [stateNotifier].
///
/// The [listener] is guaranteed to only be called once for each `state` change
/// unlike the `builder` in [StateNotifierBuilder].
///
/// ```dart
/// StateNotifierListener<MyNotifier, MyState>(
///   value: myNotifier,
///   listener: (context, state) {
///     // do stuff here based on MyNotifier's state
///   },
///   child: Container(),
/// )
/// ```
/// {@endtemplate}
///
/// {@template state_notifier_listener_listen_when}
/// An optional [listenWhen] can be implemented for more granular control
/// over when [listener] is called.
///
/// If [listenWhen] is omitted, it will default to `true`.
///
/// [listenWhen] will be invoked on each [stateNotifier] `state` change.
/// [listenWhen] takes the previous `state` and current `state` and must
/// return a [bool] which determines whether or not the [listener] function
/// will be invoked.
///
/// The previous `state` will be initialized to the `state` of the
/// [stateNotifier] when the [StateNotifierListener] is initialized.
///
/// ```dart
/// StateNotifierListener<MyNotifier, MyState>(
///   value: myNotifier,
///   listenWhen: (previous, current) {
///     // return true/false to determine whether or not
///     // to invoke listener with state
///   },
///   listener: (context, state) {
///     // do stuff here based on MyNotifier's state
///   }
///   child: Container(),
/// )
/// ```
/// {@endtemplate}
class StateNotifierListener<NotifierT extends StateNotifier<StateT>, StateT>
    extends StatefulWidget {
  /// {@macro state_notifier_listener}
  const StateNotifierListener({
    Key? key,
    required this.listener,
    required this.stateNotifier,
    required this.child,
    this.listenWhen,
  }) : super(key: key);

  /// The widget which will be rendered as a descendant of the
  /// [StateNotifierListener].
  final Widget child;

  /// The [stateNotifier] whose `state` will be listened to.
  /// Whenever the [stateNotifier]'s `state` changes, [listener] will be invoked.
  final NotifierT stateNotifier;

  /// The [StateNotifierWidgetListener] which will be called on every `state` change.
  /// This [listener] should be used for any code which needs to execute
  /// in response to a `state` change.
  final StateNotifierWidgetListener<StateT> listener;

  /// {@macro state_notifier_listener_listen_when}
  final StateNotifierListenerCondition<StateT>? listenWhen;

  @override
  _StateNotifierListenerState<NotifierT, StateT> createState() =>
      _StateNotifierListenerState<NotifierT, StateT>();
}

class _StateNotifierListenerState<NotifierT extends StateNotifier<ValueT>,
    ValueT> extends State<StateNotifierListener<NotifierT, ValueT>> {
  late NotifierT _notifier;
  late ValueT _previousState;
  StreamSubscription<ValueT>? _subscription;

  @override
  void initState() {
    super.initState();
    _notifier = widget.stateNotifier;
    // ignore: invalid_use_of_protected_member
    _previousState = _notifier.state;
    _subscribe();
  }

  @override
  void didUpdateWidget(StateNotifierListener<NotifierT, ValueT> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldNotifier = oldWidget.stateNotifier;
    final currentNotifier = widget.stateNotifier;
    if (oldNotifier != currentNotifier) {
      if (_subscription != null) {
        _unsubscribe();
        _notifier = currentNotifier;
        // ignore: invalid_use_of_protected_member
        _previousState = _notifier.state;
      }
      _subscribe();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final notifier = widget.stateNotifier;
    if (_notifier != notifier) {
      if (_subscription != null) {
        _unsubscribe();
        _notifier = notifier;
        // ignore: invalid_use_of_protected_member
        _previousState = _notifier.state;
      }
      _subscribe();
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<NotifierT>('state', _notifier));
  }

  void _subscribe() {
    _subscription = _notifier.stream.listen((state) {
      if (widget.listenWhen?.call(_previousState, state) ?? true) {
        widget.listener(context, state);
      }
      _previousState = state;
    });
  }

  void _unsubscribe() {
    _subscription?.cancel();
    _subscription = null;
  }
}
