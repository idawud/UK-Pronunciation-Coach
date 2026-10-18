// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'daily_progress.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DailyProgress {

 int get streak; int get minutesToday; int get dailyGoalMinutes; List<DateTime> get practisedDays;
/// Create a copy of DailyProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DailyProgressCopyWith<DailyProgress> get copyWith => _$DailyProgressCopyWithImpl<DailyProgress>(this as DailyProgress, _$identity);

  /// Serializes this DailyProgress to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as DailyProgress;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DailyProgress&&(identical(other.streak, _this.streak) || other.streak == _this.streak)&&(identical(other.minutesToday, _this.minutesToday) || other.minutesToday == _this.minutesToday)&&(identical(other.dailyGoalMinutes, _this.dailyGoalMinutes) || other.dailyGoalMinutes == _this.dailyGoalMinutes)&&const DeepCollectionEquality().equals(other.practisedDays, _this.practisedDays));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as DailyProgress;
  return Object.hash(runtimeType,_this.streak,_this.minutesToday,_this.dailyGoalMinutes,const DeepCollectionEquality().hash(_this.practisedDays));
}

@override
String toString() {
  final _this = this as DailyProgress;
  return 'DailyProgress(streak: ${_this.streak}, minutesToday: ${_this.minutesToday}, dailyGoalMinutes: ${_this.dailyGoalMinutes}, practisedDays: ${_this.practisedDays})';
}


}

/// @nodoc
abstract mixin class $DailyProgressCopyWith<$Res>  {
  factory $DailyProgressCopyWith(DailyProgress value, $Res Function(DailyProgress) _then) = _$DailyProgressCopyWithImpl;
@useResult
$Res call({
 int streak, int minutesToday, int dailyGoalMinutes, List<DateTime> practisedDays
});




}
/// @nodoc
class _$DailyProgressCopyWithImpl<$Res>
    implements $DailyProgressCopyWith<$Res> {
  _$DailyProgressCopyWithImpl(this._self, this._then);

  final DailyProgress _self;
  final $Res Function(DailyProgress) _then;

/// Create a copy of DailyProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? streak = null,Object? minutesToday = null,Object? dailyGoalMinutes = null,Object? practisedDays = null,}) {
  return _then(DailyProgress(
streak: null == streak ? _self.streak : streak // ignore: cast_nullable_to_non_nullable
as int,minutesToday: null == minutesToday ? _self.minutesToday : minutesToday // ignore: cast_nullable_to_non_nullable
as int,dailyGoalMinutes: null == dailyGoalMinutes ? _self.dailyGoalMinutes : dailyGoalMinutes // ignore: cast_nullable_to_non_nullable
as int,practisedDays: null == practisedDays ? _self.practisedDays : practisedDays // ignore: cast_nullable_to_non_nullable
as List<DateTime>,
  ));
}

}


/// Adds pattern-matching-related methods to [DailyProgress].
extension DailyProgressPatterns on DailyProgress {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DailyProgress value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DailyProgress() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DailyProgress value)  $default,){
final _that = this;
switch (_that) {
case _DailyProgress():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DailyProgress value)?  $default,){
final _that = this;
switch (_that) {
case _DailyProgress() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int streak,  int minutesToday,  int dailyGoalMinutes,  List<DateTime> practisedDays)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DailyProgress() when $default != null:
return $default(_that.streak,_that.minutesToday,_that.dailyGoalMinutes,_that.practisedDays);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int streak,  int minutesToday,  int dailyGoalMinutes,  List<DateTime> practisedDays)  $default,) {final _that = this;
switch (_that) {
case _DailyProgress():
return $default(_that.streak,_that.minutesToday,_that.dailyGoalMinutes,_that.practisedDays);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int streak,  int minutesToday,  int dailyGoalMinutes,  List<DateTime> practisedDays)?  $default,) {final _that = this;
switch (_that) {
case _DailyProgress() when $default != null:
return $default(_that.streak,_that.minutesToday,_that.dailyGoalMinutes,_that.practisedDays);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DailyProgress extends DailyProgress {
  const _DailyProgress({required this.streak, required this.minutesToday, required this.dailyGoalMinutes,  List<DateTime> practisedDays = const <DateTime>[]}): _practisedDays = practisedDays,super._();
  factory _DailyProgress.fromJson(Map<String, dynamic> json) => _$DailyProgressFromJson(json);

@override final  int streak;
@override final  int minutesToday;
@override final  int dailyGoalMinutes;
 final  List<DateTime> _practisedDays;
@override@JsonKey() List<DateTime> get practisedDays {
  if (_practisedDays is EqualUnmodifiableListView) return _practisedDays;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_practisedDays);
}


/// Create a copy of DailyProgress
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DailyProgressCopyWith<_DailyProgress> get copyWith => __$DailyProgressCopyWithImpl<_DailyProgress>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DailyProgressToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DailyProgress&&(identical(other.streak, streak) || other.streak == streak)&&(identical(other.minutesToday, minutesToday) || other.minutesToday == minutesToday)&&(identical(other.dailyGoalMinutes, dailyGoalMinutes) || other.dailyGoalMinutes == dailyGoalMinutes)&&const DeepCollectionEquality().equals(other.practisedDays, _practisedDays));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,streak,minutesToday,dailyGoalMinutes,const DeepCollectionEquality().hash(_practisedDays));
}

@override
String toString() {
    return 'DailyProgress(streak: $streak, minutesToday: $minutesToday, dailyGoalMinutes: $dailyGoalMinutes, practisedDays: $practisedDays)';
}


}

/// @nodoc
abstract mixin class _$DailyProgressCopyWith<$Res> implements $DailyProgressCopyWith<$Res> {
  factory _$DailyProgressCopyWith(_DailyProgress value, $Res Function(_DailyProgress) _then) = __$DailyProgressCopyWithImpl;
@override @useResult
$Res call({
 int streak, int minutesToday, int dailyGoalMinutes, List<DateTime> practisedDays
});




}
/// @nodoc
class __$DailyProgressCopyWithImpl<$Res>
    implements _$DailyProgressCopyWith<$Res> {
  __$DailyProgressCopyWithImpl(this._self, this._then);

  final _DailyProgress _self;
  final $Res Function(_DailyProgress) _then;

/// Create a copy of DailyProgress
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? streak = null,Object? minutesToday = null,Object? dailyGoalMinutes = null,Object? practisedDays = null,}) {
  return _then(_DailyProgress(
streak: null == streak ? _self.streak : streak // ignore: cast_nullable_to_non_nullable
as int,minutesToday: null == minutesToday ? _self.minutesToday : minutesToday // ignore: cast_nullable_to_non_nullable
as int,dailyGoalMinutes: null == dailyGoalMinutes ? _self.dailyGoalMinutes : dailyGoalMinutes // ignore: cast_nullable_to_non_nullable
as int,practisedDays: null == practisedDays ? _self._practisedDays : practisedDays // ignore: cast_nullable_to_non_nullable
as List<DateTime>,
  ));
}


}

// dart format on
