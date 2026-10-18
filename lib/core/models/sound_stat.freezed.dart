// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sound_stat.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SoundStat {

 String get ipa; double get accuracy; int get attempts; DateTime get lastPractised;
/// Create a copy of SoundStat
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SoundStatCopyWith<SoundStat> get copyWith => _$SoundStatCopyWithImpl<SoundStat>(this as SoundStat, _$identity);

  /// Serializes this SoundStat to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SoundStat;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SoundStat&&(identical(other.ipa, _this.ipa) || other.ipa == _this.ipa)&&(identical(other.accuracy, _this.accuracy) || other.accuracy == _this.accuracy)&&(identical(other.attempts, _this.attempts) || other.attempts == _this.attempts)&&(identical(other.lastPractised, _this.lastPractised) || other.lastPractised == _this.lastPractised));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SoundStat;
  return Object.hash(runtimeType,_this.ipa,_this.accuracy,_this.attempts,_this.lastPractised);
}

@override
String toString() {
  final _this = this as SoundStat;
  return 'SoundStat(ipa: ${_this.ipa}, accuracy: ${_this.accuracy}, attempts: ${_this.attempts}, lastPractised: ${_this.lastPractised})';
}


}

/// @nodoc
abstract mixin class $SoundStatCopyWith<$Res>  {
  factory $SoundStatCopyWith(SoundStat value, $Res Function(SoundStat) _then) = _$SoundStatCopyWithImpl;
@useResult
$Res call({
 String ipa, double accuracy, int attempts, DateTime lastPractised
});




}
/// @nodoc
class _$SoundStatCopyWithImpl<$Res>
    implements $SoundStatCopyWith<$Res> {
  _$SoundStatCopyWithImpl(this._self, this._then);

  final SoundStat _self;
  final $Res Function(SoundStat) _then;

/// Create a copy of SoundStat
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ipa = null,Object? accuracy = null,Object? attempts = null,Object? lastPractised = null,}) {
  return _then(SoundStat(
ipa: null == ipa ? _self.ipa : ipa // ignore: cast_nullable_to_non_nullable
as String,accuracy: null == accuracy ? _self.accuracy : accuracy // ignore: cast_nullable_to_non_nullable
as double,attempts: null == attempts ? _self.attempts : attempts // ignore: cast_nullable_to_non_nullable
as int,lastPractised: null == lastPractised ? _self.lastPractised : lastPractised // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [SoundStat].
extension SoundStatPatterns on SoundStat {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SoundStat value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SoundStat() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SoundStat value)  $default,){
final _that = this;
switch (_that) {
case _SoundStat():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SoundStat value)?  $default,){
final _that = this;
switch (_that) {
case _SoundStat() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String ipa,  double accuracy,  int attempts,  DateTime lastPractised)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SoundStat() when $default != null:
return $default(_that.ipa,_that.accuracy,_that.attempts,_that.lastPractised);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String ipa,  double accuracy,  int attempts,  DateTime lastPractised)  $default,) {final _that = this;
switch (_that) {
case _SoundStat():
return $default(_that.ipa,_that.accuracy,_that.attempts,_that.lastPractised);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String ipa,  double accuracy,  int attempts,  DateTime lastPractised)?  $default,) {final _that = this;
switch (_that) {
case _SoundStat() when $default != null:
return $default(_that.ipa,_that.accuracy,_that.attempts,_that.lastPractised);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SoundStat extends SoundStat {
  const _SoundStat({required this.ipa, required this.accuracy, required this.attempts, required this.lastPractised}): super._();
  factory _SoundStat.fromJson(Map<String, dynamic> json) => _$SoundStatFromJson(json);

@override final  String ipa;
@override final  double accuracy;
@override final  int attempts;
@override final  DateTime lastPractised;

/// Create a copy of SoundStat
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SoundStatCopyWith<_SoundStat> get copyWith => __$SoundStatCopyWithImpl<_SoundStat>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SoundStatToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SoundStat&&(identical(other.ipa, ipa) || other.ipa == ipa)&&(identical(other.accuracy, accuracy) || other.accuracy == accuracy)&&(identical(other.attempts, attempts) || other.attempts == attempts)&&(identical(other.lastPractised, lastPractised) || other.lastPractised == lastPractised));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,ipa,accuracy,attempts,lastPractised);
}

@override
String toString() {
    return 'SoundStat(ipa: $ipa, accuracy: $accuracy, attempts: $attempts, lastPractised: $lastPractised)';
}


}

/// @nodoc
abstract mixin class _$SoundStatCopyWith<$Res> implements $SoundStatCopyWith<$Res> {
  factory _$SoundStatCopyWith(_SoundStat value, $Res Function(_SoundStat) _then) = __$SoundStatCopyWithImpl;
@override @useResult
$Res call({
 String ipa, double accuracy, int attempts, DateTime lastPractised
});




}
/// @nodoc
class __$SoundStatCopyWithImpl<$Res>
    implements _$SoundStatCopyWith<$Res> {
  __$SoundStatCopyWithImpl(this._self, this._then);

  final _SoundStat _self;
  final $Res Function(_SoundStat) _then;

/// Create a copy of SoundStat
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ipa = null,Object? accuracy = null,Object? attempts = null,Object? lastPractised = null,}) {
  return _then(_SoundStat(
ipa: null == ipa ? _self.ipa : ipa // ignore: cast_nullable_to_non_nullable
as String,accuracy: null == accuracy ? _self.accuracy : accuracy // ignore: cast_nullable_to_non_nullable
as double,attempts: null == attempts ? _self.attempts : attempts // ignore: cast_nullable_to_non_nullable
as int,lastPractised: null == lastPractised ? _self.lastPractised : lastPractised // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
