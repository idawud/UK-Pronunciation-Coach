// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'level_change.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LevelChange {

 int get from; int get to; String get reason; DateTime get at;
/// Create a copy of LevelChange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LevelChangeCopyWith<LevelChange> get copyWith => _$LevelChangeCopyWithImpl<LevelChange>(this as LevelChange, _$identity);

  /// Serializes this LevelChange to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LevelChange;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LevelChange&&(identical(other.from, _this.from) || other.from == _this.from)&&(identical(other.to, _this.to) || other.to == _this.to)&&(identical(other.reason, _this.reason) || other.reason == _this.reason)&&(identical(other.at, _this.at) || other.at == _this.at));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LevelChange;
  return Object.hash(runtimeType,_this.from,_this.to,_this.reason,_this.at);
}

@override
String toString() {
  final _this = this as LevelChange;
  return 'LevelChange(from: ${_this.from}, to: ${_this.to}, reason: ${_this.reason}, at: ${_this.at})';
}


}

/// @nodoc
abstract mixin class $LevelChangeCopyWith<$Res>  {
  factory $LevelChangeCopyWith(LevelChange value, $Res Function(LevelChange) _then) = _$LevelChangeCopyWithImpl;
@useResult
$Res call({
 int from, int to, String reason, DateTime at
});




}
/// @nodoc
class _$LevelChangeCopyWithImpl<$Res>
    implements $LevelChangeCopyWith<$Res> {
  _$LevelChangeCopyWithImpl(this._self, this._then);

  final LevelChange _self;
  final $Res Function(LevelChange) _then;

/// Create a copy of LevelChange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? from = null,Object? to = null,Object? reason = null,Object? at = null,}) {
  return _then(LevelChange(
from: null == from ? _self.from : from // ignore: cast_nullable_to_non_nullable
as int,to: null == to ? _self.to : to // ignore: cast_nullable_to_non_nullable
as int,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [LevelChange].
extension LevelChangePatterns on LevelChange {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LevelChange value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LevelChange() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LevelChange value)  $default,){
final _that = this;
switch (_that) {
case _LevelChange():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LevelChange value)?  $default,){
final _that = this;
switch (_that) {
case _LevelChange() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int from,  int to,  String reason,  DateTime at)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LevelChange() when $default != null:
return $default(_that.from,_that.to,_that.reason,_that.at);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int from,  int to,  String reason,  DateTime at)  $default,) {final _that = this;
switch (_that) {
case _LevelChange():
return $default(_that.from,_that.to,_that.reason,_that.at);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int from,  int to,  String reason,  DateTime at)?  $default,) {final _that = this;
switch (_that) {
case _LevelChange() when $default != null:
return $default(_that.from,_that.to,_that.reason,_that.at);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LevelChange extends LevelChange {
  const _LevelChange({required this.from, required this.to, required this.reason, required this.at}): super._();
  factory _LevelChange.fromJson(Map<String, dynamic> json) => _$LevelChangeFromJson(json);

@override final  int from;
@override final  int to;
@override final  String reason;
@override final  DateTime at;

/// Create a copy of LevelChange
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LevelChangeCopyWith<_LevelChange> get copyWith => __$LevelChangeCopyWithImpl<_LevelChange>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LevelChangeToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LevelChange&&(identical(other.from, from) || other.from == from)&&(identical(other.to, to) || other.to == to)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.at, at) || other.at == at));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,from,to,reason,at);
}

@override
String toString() {
    return 'LevelChange(from: $from, to: $to, reason: $reason, at: $at)';
}


}

/// @nodoc
abstract mixin class _$LevelChangeCopyWith<$Res> implements $LevelChangeCopyWith<$Res> {
  factory _$LevelChangeCopyWith(_LevelChange value, $Res Function(_LevelChange) _then) = __$LevelChangeCopyWithImpl;
@override @useResult
$Res call({
 int from, int to, String reason, DateTime at
});




}
/// @nodoc
class __$LevelChangeCopyWithImpl<$Res>
    implements _$LevelChangeCopyWith<$Res> {
  __$LevelChangeCopyWithImpl(this._self, this._then);

  final _LevelChange _self;
  final $Res Function(_LevelChange) _then;

/// Create a copy of LevelChange
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? from = null,Object? to = null,Object? reason = null,Object? at = null,}) {
  return _then(_LevelChange(
from: null == from ? _self.from : from // ignore: cast_nullable_to_non_nullable
as int,to: null == to ? _self.to : to // ignore: cast_nullable_to_non_nullable
as int,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
