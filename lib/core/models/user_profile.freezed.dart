// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_profile.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UserProfile {

 int get level; int get dailyGoalMinutes; int get streak; DateTime? get lastPractice; bool get keepRecordings; bool get placementDone; int? get placementLevel; int? get reminderMinutes; double get textScale; ModelTier? get tierOverride; bool get onboardingDone;
/// Create a copy of UserProfile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserProfileCopyWith<UserProfile> get copyWith => _$UserProfileCopyWithImpl<UserProfile>(this as UserProfile, _$identity);

  /// Serializes this UserProfile to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as UserProfile;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserProfile&&(identical(other.level, _this.level) || other.level == _this.level)&&(identical(other.dailyGoalMinutes, _this.dailyGoalMinutes) || other.dailyGoalMinutes == _this.dailyGoalMinutes)&&(identical(other.streak, _this.streak) || other.streak == _this.streak)&&(identical(other.lastPractice, _this.lastPractice) || other.lastPractice == _this.lastPractice)&&(identical(other.keepRecordings, _this.keepRecordings) || other.keepRecordings == _this.keepRecordings)&&(identical(other.placementDone, _this.placementDone) || other.placementDone == _this.placementDone)&&(identical(other.placementLevel, _this.placementLevel) || other.placementLevel == _this.placementLevel)&&(identical(other.reminderMinutes, _this.reminderMinutes) || other.reminderMinutes == _this.reminderMinutes)&&(identical(other.textScale, _this.textScale) || other.textScale == _this.textScale)&&(identical(other.tierOverride, _this.tierOverride) || other.tierOverride == _this.tierOverride)&&(identical(other.onboardingDone, _this.onboardingDone) || other.onboardingDone == _this.onboardingDone));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as UserProfile;
  return Object.hash(runtimeType,_this.level,_this.dailyGoalMinutes,_this.streak,_this.lastPractice,_this.keepRecordings,_this.placementDone,_this.placementLevel,_this.reminderMinutes,_this.textScale,_this.tierOverride,_this.onboardingDone);
}

@override
String toString() {
  final _this = this as UserProfile;
  return 'UserProfile(level: ${_this.level}, dailyGoalMinutes: ${_this.dailyGoalMinutes}, streak: ${_this.streak}, lastPractice: ${_this.lastPractice}, keepRecordings: ${_this.keepRecordings}, placementDone: ${_this.placementDone}, placementLevel: ${_this.placementLevel}, reminderMinutes: ${_this.reminderMinutes}, textScale: ${_this.textScale}, tierOverride: ${_this.tierOverride}, onboardingDone: ${_this.onboardingDone})';
}


}

/// @nodoc
abstract mixin class $UserProfileCopyWith<$Res>  {
  factory $UserProfileCopyWith(UserProfile value, $Res Function(UserProfile) _then) = _$UserProfileCopyWithImpl;
@useResult
$Res call({
 int level, int dailyGoalMinutes, int streak, DateTime? lastPractice, bool keepRecordings, bool placementDone, int? placementLevel, int? reminderMinutes, double textScale, ModelTier? tierOverride, bool onboardingDone
});




}
/// @nodoc
class _$UserProfileCopyWithImpl<$Res>
    implements $UserProfileCopyWith<$Res> {
  _$UserProfileCopyWithImpl(this._self, this._then);

  final UserProfile _self;
  final $Res Function(UserProfile) _then;

/// Create a copy of UserProfile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? level = null,Object? dailyGoalMinutes = null,Object? streak = null,Object? lastPractice = freezed,Object? keepRecordings = null,Object? placementDone = null,Object? placementLevel = freezed,Object? reminderMinutes = freezed,Object? textScale = null,Object? tierOverride = freezed,Object? onboardingDone = null,}) {
  return _then(UserProfile(
level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,dailyGoalMinutes: null == dailyGoalMinutes ? _self.dailyGoalMinutes : dailyGoalMinutes // ignore: cast_nullable_to_non_nullable
as int,streak: null == streak ? _self.streak : streak // ignore: cast_nullable_to_non_nullable
as int,lastPractice: freezed == lastPractice ? _self.lastPractice : lastPractice // ignore: cast_nullable_to_non_nullable
as DateTime?,keepRecordings: null == keepRecordings ? _self.keepRecordings : keepRecordings // ignore: cast_nullable_to_non_nullable
as bool,placementDone: null == placementDone ? _self.placementDone : placementDone // ignore: cast_nullable_to_non_nullable
as bool,placementLevel: freezed == placementLevel ? _self.placementLevel : placementLevel // ignore: cast_nullable_to_non_nullable
as int?,reminderMinutes: freezed == reminderMinutes ? _self.reminderMinutes : reminderMinutes // ignore: cast_nullable_to_non_nullable
as int?,textScale: null == textScale ? _self.textScale : textScale // ignore: cast_nullable_to_non_nullable
as double,tierOverride: freezed == tierOverride ? _self.tierOverride : tierOverride // ignore: cast_nullable_to_non_nullable
as ModelTier?,onboardingDone: null == onboardingDone ? _self.onboardingDone : onboardingDone // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [UserProfile].
extension UserProfilePatterns on UserProfile {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserProfile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserProfile() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserProfile value)  $default,){
final _that = this;
switch (_that) {
case _UserProfile():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserProfile value)?  $default,){
final _that = this;
switch (_that) {
case _UserProfile() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int level,  int dailyGoalMinutes,  int streak,  DateTime? lastPractice,  bool keepRecordings,  bool placementDone,  int? placementLevel,  int? reminderMinutes,  double textScale,  ModelTier? tierOverride,  bool onboardingDone)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserProfile() when $default != null:
return $default(_that.level,_that.dailyGoalMinutes,_that.streak,_that.lastPractice,_that.keepRecordings,_that.placementDone,_that.placementLevel,_that.reminderMinutes,_that.textScale,_that.tierOverride,_that.onboardingDone);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int level,  int dailyGoalMinutes,  int streak,  DateTime? lastPractice,  bool keepRecordings,  bool placementDone,  int? placementLevel,  int? reminderMinutes,  double textScale,  ModelTier? tierOverride,  bool onboardingDone)  $default,) {final _that = this;
switch (_that) {
case _UserProfile():
return $default(_that.level,_that.dailyGoalMinutes,_that.streak,_that.lastPractice,_that.keepRecordings,_that.placementDone,_that.placementLevel,_that.reminderMinutes,_that.textScale,_that.tierOverride,_that.onboardingDone);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int level,  int dailyGoalMinutes,  int streak,  DateTime? lastPractice,  bool keepRecordings,  bool placementDone,  int? placementLevel,  int? reminderMinutes,  double textScale,  ModelTier? tierOverride,  bool onboardingDone)?  $default,) {final _that = this;
switch (_that) {
case _UserProfile() when $default != null:
return $default(_that.level,_that.dailyGoalMinutes,_that.streak,_that.lastPractice,_that.keepRecordings,_that.placementDone,_that.placementLevel,_that.reminderMinutes,_that.textScale,_that.tierOverride,_that.onboardingDone);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserProfile implements UserProfile {
  const _UserProfile({this.level = 1, this.dailyGoalMinutes = 10, this.streak = 0, this.lastPractice, this.keepRecordings = false, this.placementDone = false, this.placementLevel, this.reminderMinutes, this.textScale = 1.0, this.tierOverride, this.onboardingDone = false});
  factory _UserProfile.fromJson(Map<String, dynamic> json) => _$UserProfileFromJson(json);

@override@JsonKey() final  int level;
@override@JsonKey() final  int dailyGoalMinutes;
@override@JsonKey() final  int streak;
@override final  DateTime? lastPractice;
@override@JsonKey() final  bool keepRecordings;
@override@JsonKey() final  bool placementDone;
@override final  int? placementLevel;
@override final  int? reminderMinutes;
@override@JsonKey() final  double textScale;
@override final  ModelTier? tierOverride;
@override@JsonKey() final  bool onboardingDone;

/// Create a copy of UserProfile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserProfileCopyWith<_UserProfile> get copyWith => __$UserProfileCopyWithImpl<_UserProfile>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserProfileToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserProfile&&(identical(other.level, level) || other.level == level)&&(identical(other.dailyGoalMinutes, dailyGoalMinutes) || other.dailyGoalMinutes == dailyGoalMinutes)&&(identical(other.streak, streak) || other.streak == streak)&&(identical(other.lastPractice, lastPractice) || other.lastPractice == lastPractice)&&(identical(other.keepRecordings, keepRecordings) || other.keepRecordings == keepRecordings)&&(identical(other.placementDone, placementDone) || other.placementDone == placementDone)&&(identical(other.placementLevel, placementLevel) || other.placementLevel == placementLevel)&&(identical(other.reminderMinutes, reminderMinutes) || other.reminderMinutes == reminderMinutes)&&(identical(other.textScale, textScale) || other.textScale == textScale)&&(identical(other.tierOverride, tierOverride) || other.tierOverride == tierOverride)&&(identical(other.onboardingDone, onboardingDone) || other.onboardingDone == onboardingDone));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,level,dailyGoalMinutes,streak,lastPractice,keepRecordings,placementDone,placementLevel,reminderMinutes,textScale,tierOverride,onboardingDone);
}

@override
String toString() {
    return 'UserProfile(level: $level, dailyGoalMinutes: $dailyGoalMinutes, streak: $streak, lastPractice: $lastPractice, keepRecordings: $keepRecordings, placementDone: $placementDone, placementLevel: $placementLevel, reminderMinutes: $reminderMinutes, textScale: $textScale, tierOverride: $tierOverride, onboardingDone: $onboardingDone)';
}


}

/// @nodoc
abstract mixin class _$UserProfileCopyWith<$Res> implements $UserProfileCopyWith<$Res> {
  factory _$UserProfileCopyWith(_UserProfile value, $Res Function(_UserProfile) _then) = __$UserProfileCopyWithImpl;
@override @useResult
$Res call({
 int level, int dailyGoalMinutes, int streak, DateTime? lastPractice, bool keepRecordings, bool placementDone, int? placementLevel, int? reminderMinutes, double textScale, ModelTier? tierOverride, bool onboardingDone
});




}
/// @nodoc
class __$UserProfileCopyWithImpl<$Res>
    implements _$UserProfileCopyWith<$Res> {
  __$UserProfileCopyWithImpl(this._self, this._then);

  final _UserProfile _self;
  final $Res Function(_UserProfile) _then;

/// Create a copy of UserProfile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? level = null,Object? dailyGoalMinutes = null,Object? streak = null,Object? lastPractice = freezed,Object? keepRecordings = null,Object? placementDone = null,Object? placementLevel = freezed,Object? reminderMinutes = freezed,Object? textScale = null,Object? tierOverride = freezed,Object? onboardingDone = null,}) {
  return _then(_UserProfile(
level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,dailyGoalMinutes: null == dailyGoalMinutes ? _self.dailyGoalMinutes : dailyGoalMinutes // ignore: cast_nullable_to_non_nullable
as int,streak: null == streak ? _self.streak : streak // ignore: cast_nullable_to_non_nullable
as int,lastPractice: freezed == lastPractice ? _self.lastPractice : lastPractice // ignore: cast_nullable_to_non_nullable
as DateTime?,keepRecordings: null == keepRecordings ? _self.keepRecordings : keepRecordings // ignore: cast_nullable_to_non_nullable
as bool,placementDone: null == placementDone ? _self.placementDone : placementDone // ignore: cast_nullable_to_non_nullable
as bool,placementLevel: freezed == placementLevel ? _self.placementLevel : placementLevel // ignore: cast_nullable_to_non_nullable
as int?,reminderMinutes: freezed == reminderMinutes ? _self.reminderMinutes : reminderMinutes // ignore: cast_nullable_to_non_nullable
as int?,textScale: null == textScale ? _self.textScale : textScale // ignore: cast_nullable_to_non_nullable
as double,tierOverride: freezed == tierOverride ? _self.tierOverride : tierOverride // ignore: cast_nullable_to_non_nullable
as ModelTier?,onboardingDone: null == onboardingDone ? _self.onboardingDone : onboardingDone // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
