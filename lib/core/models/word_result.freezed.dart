// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'word_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WordResult {

 int get index; String get text; int get score; List<PhonemeResult> get phonemes; WordStatus get status;
/// Create a copy of WordResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WordResultCopyWith<WordResult> get copyWith => _$WordResultCopyWithImpl<WordResult>(this as WordResult, _$identity);

  /// Serializes this WordResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as WordResult;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WordResult&&(identical(other.index, _this.index) || other.index == _this.index)&&(identical(other.text, _this.text) || other.text == _this.text)&&(identical(other.score, _this.score) || other.score == _this.score)&&const DeepCollectionEquality().equals(other.phonemes, _this.phonemes)&&(identical(other.status, _this.status) || other.status == _this.status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as WordResult;
  return Object.hash(runtimeType,_this.index,_this.text,_this.score,const DeepCollectionEquality().hash(_this.phonemes),_this.status);
}

@override
String toString() {
  final _this = this as WordResult;
  return 'WordResult(index: ${_this.index}, text: ${_this.text}, score: ${_this.score}, phonemes: ${_this.phonemes}, status: ${_this.status})';
}


}

/// @nodoc
abstract mixin class $WordResultCopyWith<$Res>  {
  factory $WordResultCopyWith(WordResult value, $Res Function(WordResult) _then) = _$WordResultCopyWithImpl;
@useResult
$Res call({
 int index, String text, int score, List<PhonemeResult> phonemes, WordStatus status
});




}
/// @nodoc
class _$WordResultCopyWithImpl<$Res>
    implements $WordResultCopyWith<$Res> {
  _$WordResultCopyWithImpl(this._self, this._then);

  final WordResult _self;
  final $Res Function(WordResult) _then;

/// Create a copy of WordResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? index = null,Object? text = null,Object? score = null,Object? phonemes = null,Object? status = null,}) {
  return _then(WordResult(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,phonemes: null == phonemes ? _self.phonemes : phonemes // ignore: cast_nullable_to_non_nullable
as List<PhonemeResult>,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as WordStatus,
  ));
}

}


/// Adds pattern-matching-related methods to [WordResult].
extension WordResultPatterns on WordResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WordResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WordResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WordResult value)  $default,){
final _that = this;
switch (_that) {
case _WordResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WordResult value)?  $default,){
final _that = this;
switch (_that) {
case _WordResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int index,  String text,  int score,  List<PhonemeResult> phonemes,  WordStatus status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WordResult() when $default != null:
return $default(_that.index,_that.text,_that.score,_that.phonemes,_that.status);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int index,  String text,  int score,  List<PhonemeResult> phonemes,  WordStatus status)  $default,) {final _that = this;
switch (_that) {
case _WordResult():
return $default(_that.index,_that.text,_that.score,_that.phonemes,_that.status);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int index,  String text,  int score,  List<PhonemeResult> phonemes,  WordStatus status)?  $default,) {final _that = this;
switch (_that) {
case _WordResult() when $default != null:
return $default(_that.index,_that.text,_that.score,_that.phonemes,_that.status);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WordResult implements WordResult {
  const _WordResult({required this.index, required this.text, required this.score,  List<PhonemeResult> phonemes = const <PhonemeResult>[], required this.status}): _phonemes = phonemes;
  factory _WordResult.fromJson(Map<String, dynamic> json) => _$WordResultFromJson(json);

@override final  int index;
@override final  String text;
@override final  int score;
 final  List<PhonemeResult> _phonemes;
@override@JsonKey() List<PhonemeResult> get phonemes {
  if (_phonemes is EqualUnmodifiableListView) return _phonemes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_phonemes);
}

@override final  WordStatus status;

/// Create a copy of WordResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WordResultCopyWith<_WordResult> get copyWith => __$WordResultCopyWithImpl<_WordResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WordResultToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WordResult&&(identical(other.index, index) || other.index == index)&&(identical(other.text, text) || other.text == text)&&(identical(other.score, score) || other.score == score)&&const DeepCollectionEquality().equals(other.phonemes, _phonemes)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,index,text,score,const DeepCollectionEquality().hash(_phonemes),status);
}

@override
String toString() {
    return 'WordResult(index: $index, text: $text, score: $score, phonemes: $phonemes, status: $status)';
}


}

/// @nodoc
abstract mixin class _$WordResultCopyWith<$Res> implements $WordResultCopyWith<$Res> {
  factory _$WordResultCopyWith(_WordResult value, $Res Function(_WordResult) _then) = __$WordResultCopyWithImpl;
@override @useResult
$Res call({
 int index, String text, int score, List<PhonemeResult> phonemes, WordStatus status
});




}
/// @nodoc
class __$WordResultCopyWithImpl<$Res>
    implements _$WordResultCopyWith<$Res> {
  __$WordResultCopyWithImpl(this._self, this._then);

  final _WordResult _self;
  final $Res Function(_WordResult) _then;

/// Create a copy of WordResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? index = null,Object? text = null,Object? score = null,Object? phonemes = null,Object? status = null,}) {
  return _then(_WordResult(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,phonemes: null == phonemes ? _self._phonemes : phonemes // ignore: cast_nullable_to_non_nullable
as List<PhonemeResult>,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as WordStatus,
  ));
}


}

// dart format on
