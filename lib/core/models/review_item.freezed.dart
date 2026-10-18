// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'review_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ReviewItem {

 String get word; List<PhonemeSpec> get phonemes; DateTime get due; int get intervalDays; double get ease; int get stage; int? get lastScore; String? get passageId;
/// Create a copy of ReviewItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReviewItemCopyWith<ReviewItem> get copyWith => _$ReviewItemCopyWithImpl<ReviewItem>(this as ReviewItem, _$identity);

  /// Serializes this ReviewItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ReviewItem;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReviewItem&&(identical(other.word, _this.word) || other.word == _this.word)&&const DeepCollectionEquality().equals(other.phonemes, _this.phonemes)&&(identical(other.due, _this.due) || other.due == _this.due)&&(identical(other.intervalDays, _this.intervalDays) || other.intervalDays == _this.intervalDays)&&(identical(other.ease, _this.ease) || other.ease == _this.ease)&&(identical(other.stage, _this.stage) || other.stage == _this.stage)&&(identical(other.lastScore, _this.lastScore) || other.lastScore == _this.lastScore)&&(identical(other.passageId, _this.passageId) || other.passageId == _this.passageId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ReviewItem;
  return Object.hash(runtimeType,_this.word,const DeepCollectionEquality().hash(_this.phonemes),_this.due,_this.intervalDays,_this.ease,_this.stage,_this.lastScore,_this.passageId);
}

@override
String toString() {
  final _this = this as ReviewItem;
  return 'ReviewItem(word: ${_this.word}, phonemes: ${_this.phonemes}, due: ${_this.due}, intervalDays: ${_this.intervalDays}, ease: ${_this.ease}, stage: ${_this.stage}, lastScore: ${_this.lastScore}, passageId: ${_this.passageId})';
}


}

/// @nodoc
abstract mixin class $ReviewItemCopyWith<$Res>  {
  factory $ReviewItemCopyWith(ReviewItem value, $Res Function(ReviewItem) _then) = _$ReviewItemCopyWithImpl;
@useResult
$Res call({
 String word, List<PhonemeSpec> phonemes, DateTime due, int intervalDays, double ease, int stage, int? lastScore, String? passageId
});




}
/// @nodoc
class _$ReviewItemCopyWithImpl<$Res>
    implements $ReviewItemCopyWith<$Res> {
  _$ReviewItemCopyWithImpl(this._self, this._then);

  final ReviewItem _self;
  final $Res Function(ReviewItem) _then;

/// Create a copy of ReviewItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? word = null,Object? phonemes = null,Object? due = null,Object? intervalDays = null,Object? ease = null,Object? stage = null,Object? lastScore = freezed,Object? passageId = freezed,}) {
  return _then(ReviewItem(
word: null == word ? _self.word : word // ignore: cast_nullable_to_non_nullable
as String,phonemes: null == phonemes ? _self.phonemes : phonemes // ignore: cast_nullable_to_non_nullable
as List<PhonemeSpec>,due: null == due ? _self.due : due // ignore: cast_nullable_to_non_nullable
as DateTime,intervalDays: null == intervalDays ? _self.intervalDays : intervalDays // ignore: cast_nullable_to_non_nullable
as int,ease: null == ease ? _self.ease : ease // ignore: cast_nullable_to_non_nullable
as double,stage: null == stage ? _self.stage : stage // ignore: cast_nullable_to_non_nullable
as int,lastScore: freezed == lastScore ? _self.lastScore : lastScore // ignore: cast_nullable_to_non_nullable
as int?,passageId: freezed == passageId ? _self.passageId : passageId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ReviewItem].
extension ReviewItemPatterns on ReviewItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReviewItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReviewItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReviewItem value)  $default,){
final _that = this;
switch (_that) {
case _ReviewItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReviewItem value)?  $default,){
final _that = this;
switch (_that) {
case _ReviewItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String word,  List<PhonemeSpec> phonemes,  DateTime due,  int intervalDays,  double ease,  int stage,  int? lastScore,  String? passageId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReviewItem() when $default != null:
return $default(_that.word,_that.phonemes,_that.due,_that.intervalDays,_that.ease,_that.stage,_that.lastScore,_that.passageId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String word,  List<PhonemeSpec> phonemes,  DateTime due,  int intervalDays,  double ease,  int stage,  int? lastScore,  String? passageId)  $default,) {final _that = this;
switch (_that) {
case _ReviewItem():
return $default(_that.word,_that.phonemes,_that.due,_that.intervalDays,_that.ease,_that.stage,_that.lastScore,_that.passageId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String word,  List<PhonemeSpec> phonemes,  DateTime due,  int intervalDays,  double ease,  int stage,  int? lastScore,  String? passageId)?  $default,) {final _that = this;
switch (_that) {
case _ReviewItem() when $default != null:
return $default(_that.word,_that.phonemes,_that.due,_that.intervalDays,_that.ease,_that.stage,_that.lastScore,_that.passageId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ReviewItem extends ReviewItem {
  const _ReviewItem({required this.word,  List<PhonemeSpec> phonemes = const <PhonemeSpec>[], required this.due, required this.intervalDays, this.ease = 2.5, this.stage = 0, this.lastScore, this.passageId}): _phonemes = phonemes,super._();
  factory _ReviewItem.fromJson(Map<String, dynamic> json) => _$ReviewItemFromJson(json);

@override final  String word;
 final  List<PhonemeSpec> _phonemes;
@override@JsonKey() List<PhonemeSpec> get phonemes {
  if (_phonemes is EqualUnmodifiableListView) return _phonemes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_phonemes);
}

@override final  DateTime due;
@override final  int intervalDays;
@override@JsonKey() final  double ease;
@override@JsonKey() final  int stage;
@override final  int? lastScore;
@override final  String? passageId;

/// Create a copy of ReviewItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReviewItemCopyWith<_ReviewItem> get copyWith => __$ReviewItemCopyWithImpl<_ReviewItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReviewItemToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReviewItem&&(identical(other.word, word) || other.word == word)&&const DeepCollectionEquality().equals(other.phonemes, _phonemes)&&(identical(other.due, due) || other.due == due)&&(identical(other.intervalDays, intervalDays) || other.intervalDays == intervalDays)&&(identical(other.ease, ease) || other.ease == ease)&&(identical(other.stage, stage) || other.stage == stage)&&(identical(other.lastScore, lastScore) || other.lastScore == lastScore)&&(identical(other.passageId, passageId) || other.passageId == passageId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,word,const DeepCollectionEquality().hash(_phonemes),due,intervalDays,ease,stage,lastScore,passageId);
}

@override
String toString() {
    return 'ReviewItem(word: $word, phonemes: $phonemes, due: $due, intervalDays: $intervalDays, ease: $ease, stage: $stage, lastScore: $lastScore, passageId: $passageId)';
}


}

/// @nodoc
abstract mixin class _$ReviewItemCopyWith<$Res> implements $ReviewItemCopyWith<$Res> {
  factory _$ReviewItemCopyWith(_ReviewItem value, $Res Function(_ReviewItem) _then) = __$ReviewItemCopyWithImpl;
@override @useResult
$Res call({
 String word, List<PhonemeSpec> phonemes, DateTime due, int intervalDays, double ease, int stage, int? lastScore, String? passageId
});




}
/// @nodoc
class __$ReviewItemCopyWithImpl<$Res>
    implements _$ReviewItemCopyWith<$Res> {
  __$ReviewItemCopyWithImpl(this._self, this._then);

  final _ReviewItem _self;
  final $Res Function(_ReviewItem) _then;

/// Create a copy of ReviewItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? word = null,Object? phonemes = null,Object? due = null,Object? intervalDays = null,Object? ease = null,Object? stage = null,Object? lastScore = freezed,Object? passageId = freezed,}) {
  return _then(_ReviewItem(
word: null == word ? _self.word : word // ignore: cast_nullable_to_non_nullable
as String,phonemes: null == phonemes ? _self._phonemes : phonemes // ignore: cast_nullable_to_non_nullable
as List<PhonemeSpec>,due: null == due ? _self.due : due // ignore: cast_nullable_to_non_nullable
as DateTime,intervalDays: null == intervalDays ? _self.intervalDays : intervalDays // ignore: cast_nullable_to_non_nullable
as int,ease: null == ease ? _self.ease : ease // ignore: cast_nullable_to_non_nullable
as double,stage: null == stage ? _self.stage : stage // ignore: cast_nullable_to_non_nullable
as int,lastScore: freezed == lastScore ? _self.lastScore : lastScore // ignore: cast_nullable_to_non_nullable
as int?,passageId: freezed == passageId ? _self.passageId : passageId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
