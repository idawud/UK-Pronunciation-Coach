// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'practice_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PracticeSession {

 DateTime get start; Duration get duration;
/// Create a copy of PracticeSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PracticeSessionCopyWith<PracticeSession> get copyWith => _$PracticeSessionCopyWithImpl<PracticeSession>(this as PracticeSession, _$identity);

  /// Serializes this PracticeSession to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PracticeSession;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PracticeSession&&(identical(other.start, _this.start) || other.start == _this.start)&&(identical(other.duration, _this.duration) || other.duration == _this.duration));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PracticeSession;
  return Object.hash(runtimeType,_this.start,_this.duration);
}

@override
String toString() {
  final _this = this as PracticeSession;
  return 'PracticeSession(start: ${_this.start}, duration: ${_this.duration})';
}


}

/// @nodoc
abstract mixin class $PracticeSessionCopyWith<$Res>  {
  factory $PracticeSessionCopyWith(PracticeSession value, $Res Function(PracticeSession) _then) = _$PracticeSessionCopyWithImpl;
@useResult
$Res call({
 DateTime start, Duration duration
});




}
/// @nodoc
class _$PracticeSessionCopyWithImpl<$Res>
    implements $PracticeSessionCopyWith<$Res> {
  _$PracticeSessionCopyWithImpl(this._self, this._then);

  final PracticeSession _self;
  final $Res Function(PracticeSession) _then;

/// Create a copy of PracticeSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? start = null,Object? duration = null,}) {
  return _then(PracticeSession(
start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as DateTime,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration,
  ));
}

}


/// Adds pattern-matching-related methods to [PracticeSession].
extension PracticeSessionPatterns on PracticeSession {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PracticeSession value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PracticeSession() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PracticeSession value)  $default,){
final _that = this;
switch (_that) {
case _PracticeSession():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PracticeSession value)?  $default,){
final _that = this;
switch (_that) {
case _PracticeSession() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DateTime start,  Duration duration)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PracticeSession() when $default != null:
return $default(_that.start,_that.duration);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DateTime start,  Duration duration)  $default,) {final _that = this;
switch (_that) {
case _PracticeSession():
return $default(_that.start,_that.duration);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DateTime start,  Duration duration)?  $default,) {final _that = this;
switch (_that) {
case _PracticeSession() when $default != null:
return $default(_that.start,_that.duration);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PracticeSession implements PracticeSession {
  const _PracticeSession({required this.start, required this.duration});
  factory _PracticeSession.fromJson(Map<String, dynamic> json) => _$PracticeSessionFromJson(json);

@override final  DateTime start;
@override final  Duration duration;

/// Create a copy of PracticeSession
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PracticeSessionCopyWith<_PracticeSession> get copyWith => __$PracticeSessionCopyWithImpl<_PracticeSession>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PracticeSessionToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PracticeSession&&(identical(other.start, start) || other.start == start)&&(identical(other.duration, duration) || other.duration == duration));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,start,duration);
}

@override
String toString() {
    return 'PracticeSession(start: $start, duration: $duration)';
}


}

/// @nodoc
abstract mixin class _$PracticeSessionCopyWith<$Res> implements $PracticeSessionCopyWith<$Res> {
  factory _$PracticeSessionCopyWith(_PracticeSession value, $Res Function(_PracticeSession) _then) = __$PracticeSessionCopyWithImpl;
@override @useResult
$Res call({
 DateTime start, Duration duration
});




}
/// @nodoc
class __$PracticeSessionCopyWithImpl<$Res>
    implements _$PracticeSessionCopyWith<$Res> {
  __$PracticeSessionCopyWithImpl(this._self, this._then);

  final _PracticeSession _self;
  final $Res Function(_PracticeSession) _then;

/// Create a copy of PracticeSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? start = null,Object? duration = null,}) {
  return _then(_PracticeSession(
start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as DateTime,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration,
  ));
}


}

// dart format on
