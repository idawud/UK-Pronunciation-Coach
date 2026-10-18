// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'phoneme_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PhonemeResult {

 String get expected; String? get heard; int get score; Duration get start; Duration get end;
/// Create a copy of PhonemeResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PhonemeResultCopyWith<PhonemeResult> get copyWith => _$PhonemeResultCopyWithImpl<PhonemeResult>(this as PhonemeResult, _$identity);

  /// Serializes this PhonemeResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PhonemeResult;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PhonemeResult&&(identical(other.expected, _this.expected) || other.expected == _this.expected)&&(identical(other.heard, _this.heard) || other.heard == _this.heard)&&(identical(other.score, _this.score) || other.score == _this.score)&&(identical(other.start, _this.start) || other.start == _this.start)&&(identical(other.end, _this.end) || other.end == _this.end));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PhonemeResult;
  return Object.hash(runtimeType,_this.expected,_this.heard,_this.score,_this.start,_this.end);
}

@override
String toString() {
  final _this = this as PhonemeResult;
  return 'PhonemeResult(expected: ${_this.expected}, heard: ${_this.heard}, score: ${_this.score}, start: ${_this.start}, end: ${_this.end})';
}


}

/// @nodoc
abstract mixin class $PhonemeResultCopyWith<$Res>  {
  factory $PhonemeResultCopyWith(PhonemeResult value, $Res Function(PhonemeResult) _then) = _$PhonemeResultCopyWithImpl;
@useResult
$Res call({
 String expected, String? heard, int score, Duration start, Duration end
});




}
/// @nodoc
class _$PhonemeResultCopyWithImpl<$Res>
    implements $PhonemeResultCopyWith<$Res> {
  _$PhonemeResultCopyWithImpl(this._self, this._then);

  final PhonemeResult _self;
  final $Res Function(PhonemeResult) _then;

/// Create a copy of PhonemeResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? expected = null,Object? heard = freezed,Object? score = null,Object? start = null,Object? end = null,}) {
  return _then(PhonemeResult(
expected: null == expected ? _self.expected : expected // ignore: cast_nullable_to_non_nullable
as String,heard: freezed == heard ? _self.heard : heard // ignore: cast_nullable_to_non_nullable
as String?,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as Duration,end: null == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as Duration,
  ));
}

}


/// Adds pattern-matching-related methods to [PhonemeResult].
extension PhonemeResultPatterns on PhonemeResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PhonemeResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PhonemeResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PhonemeResult value)  $default,){
final _that = this;
switch (_that) {
case _PhonemeResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PhonemeResult value)?  $default,){
final _that = this;
switch (_that) {
case _PhonemeResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String expected,  String? heard,  int score,  Duration start,  Duration end)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PhonemeResult() when $default != null:
return $default(_that.expected,_that.heard,_that.score,_that.start,_that.end);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String expected,  String? heard,  int score,  Duration start,  Duration end)  $default,) {final _that = this;
switch (_that) {
case _PhonemeResult():
return $default(_that.expected,_that.heard,_that.score,_that.start,_that.end);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String expected,  String? heard,  int score,  Duration start,  Duration end)?  $default,) {final _that = this;
switch (_that) {
case _PhonemeResult() when $default != null:
return $default(_that.expected,_that.heard,_that.score,_that.start,_that.end);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PhonemeResult implements PhonemeResult {
  const _PhonemeResult({required this.expected, this.heard, required this.score, required this.start, required this.end});
  factory _PhonemeResult.fromJson(Map<String, dynamic> json) => _$PhonemeResultFromJson(json);

@override final  String expected;
@override final  String? heard;
@override final  int score;
@override final  Duration start;
@override final  Duration end;

/// Create a copy of PhonemeResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PhonemeResultCopyWith<_PhonemeResult> get copyWith => __$PhonemeResultCopyWithImpl<_PhonemeResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PhonemeResultToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PhonemeResult&&(identical(other.expected, expected) || other.expected == expected)&&(identical(other.heard, heard) || other.heard == heard)&&(identical(other.score, score) || other.score == score)&&(identical(other.start, start) || other.start == start)&&(identical(other.end, end) || other.end == end));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,expected,heard,score,start,end);
}

@override
String toString() {
    return 'PhonemeResult(expected: $expected, heard: $heard, score: $score, start: $start, end: $end)';
}


}

/// @nodoc
abstract mixin class _$PhonemeResultCopyWith<$Res> implements $PhonemeResultCopyWith<$Res> {
  factory _$PhonemeResultCopyWith(_PhonemeResult value, $Res Function(_PhonemeResult) _then) = __$PhonemeResultCopyWithImpl;
@override @useResult
$Res call({
 String expected, String? heard, int score, Duration start, Duration end
});




}
/// @nodoc
class __$PhonemeResultCopyWithImpl<$Res>
    implements _$PhonemeResultCopyWith<$Res> {
  __$PhonemeResultCopyWithImpl(this._self, this._then);

  final _PhonemeResult _self;
  final $Res Function(_PhonemeResult) _then;

/// Create a copy of PhonemeResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? expected = null,Object? heard = freezed,Object? score = null,Object? start = null,Object? end = null,}) {
  return _then(_PhonemeResult(
expected: null == expected ? _self.expected : expected // ignore: cast_nullable_to_non_nullable
as String,heard: freezed == heard ? _self.heard : heard // ignore: cast_nullable_to_non_nullable
as String?,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as Duration,end: null == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as Duration,
  ));
}


}

// dart format on
