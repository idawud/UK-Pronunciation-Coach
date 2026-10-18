// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'attempt_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AttemptResult {

 String get id; String get passageId; DateTime get at; int get overall; int get accuracy; int get fluency; List<WordResult> get words; String? get audioPath; ModelTier get tier;
/// Create a copy of AttemptResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AttemptResultCopyWith<AttemptResult> get copyWith => _$AttemptResultCopyWithImpl<AttemptResult>(this as AttemptResult, _$identity);

  /// Serializes this AttemptResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AttemptResult;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AttemptResult&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.passageId, _this.passageId) || other.passageId == _this.passageId)&&(identical(other.at, _this.at) || other.at == _this.at)&&(identical(other.overall, _this.overall) || other.overall == _this.overall)&&(identical(other.accuracy, _this.accuracy) || other.accuracy == _this.accuracy)&&(identical(other.fluency, _this.fluency) || other.fluency == _this.fluency)&&const DeepCollectionEquality().equals(other.words, _this.words)&&(identical(other.audioPath, _this.audioPath) || other.audioPath == _this.audioPath)&&(identical(other.tier, _this.tier) || other.tier == _this.tier));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AttemptResult;
  return Object.hash(runtimeType,_this.id,_this.passageId,_this.at,_this.overall,_this.accuracy,_this.fluency,const DeepCollectionEquality().hash(_this.words),_this.audioPath,_this.tier);
}

@override
String toString() {
  final _this = this as AttemptResult;
  return 'AttemptResult(id: ${_this.id}, passageId: ${_this.passageId}, at: ${_this.at}, overall: ${_this.overall}, accuracy: ${_this.accuracy}, fluency: ${_this.fluency}, words: ${_this.words}, audioPath: ${_this.audioPath}, tier: ${_this.tier})';
}


}

/// @nodoc
abstract mixin class $AttemptResultCopyWith<$Res>  {
  factory $AttemptResultCopyWith(AttemptResult value, $Res Function(AttemptResult) _then) = _$AttemptResultCopyWithImpl;
@useResult
$Res call({
 String id, String passageId, DateTime at, int overall, int accuracy, int fluency, List<WordResult> words, String? audioPath, ModelTier tier
});




}
/// @nodoc
class _$AttemptResultCopyWithImpl<$Res>
    implements $AttemptResultCopyWith<$Res> {
  _$AttemptResultCopyWithImpl(this._self, this._then);

  final AttemptResult _self;
  final $Res Function(AttemptResult) _then;

/// Create a copy of AttemptResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? passageId = null,Object? at = null,Object? overall = null,Object? accuracy = null,Object? fluency = null,Object? words = null,Object? audioPath = freezed,Object? tier = null,}) {
  return _then(AttemptResult(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,passageId: null == passageId ? _self.passageId : passageId // ignore: cast_nullable_to_non_nullable
as String,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,overall: null == overall ? _self.overall : overall // ignore: cast_nullable_to_non_nullable
as int,accuracy: null == accuracy ? _self.accuracy : accuracy // ignore: cast_nullable_to_non_nullable
as int,fluency: null == fluency ? _self.fluency : fluency // ignore: cast_nullable_to_non_nullable
as int,words: null == words ? _self.words : words // ignore: cast_nullable_to_non_nullable
as List<WordResult>,audioPath: freezed == audioPath ? _self.audioPath : audioPath // ignore: cast_nullable_to_non_nullable
as String?,tier: null == tier ? _self.tier : tier // ignore: cast_nullable_to_non_nullable
as ModelTier,
  ));
}

}


/// Adds pattern-matching-related methods to [AttemptResult].
extension AttemptResultPatterns on AttemptResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AttemptResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AttemptResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AttemptResult value)  $default,){
final _that = this;
switch (_that) {
case _AttemptResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AttemptResult value)?  $default,){
final _that = this;
switch (_that) {
case _AttemptResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String passageId,  DateTime at,  int overall,  int accuracy,  int fluency,  List<WordResult> words,  String? audioPath,  ModelTier tier)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AttemptResult() when $default != null:
return $default(_that.id,_that.passageId,_that.at,_that.overall,_that.accuracy,_that.fluency,_that.words,_that.audioPath,_that.tier);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String passageId,  DateTime at,  int overall,  int accuracy,  int fluency,  List<WordResult> words,  String? audioPath,  ModelTier tier)  $default,) {final _that = this;
switch (_that) {
case _AttemptResult():
return $default(_that.id,_that.passageId,_that.at,_that.overall,_that.accuracy,_that.fluency,_that.words,_that.audioPath,_that.tier);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String passageId,  DateTime at,  int overall,  int accuracy,  int fluency,  List<WordResult> words,  String? audioPath,  ModelTier tier)?  $default,) {final _that = this;
switch (_that) {
case _AttemptResult() when $default != null:
return $default(_that.id,_that.passageId,_that.at,_that.overall,_that.accuracy,_that.fluency,_that.words,_that.audioPath,_that.tier);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AttemptResult extends AttemptResult {
  const _AttemptResult({required this.id, required this.passageId, required this.at, required this.overall, required this.accuracy, required this.fluency, required  List<WordResult> words, this.audioPath, this.tier = ModelTier.full}): _words = words,super._();
  factory _AttemptResult.fromJson(Map<String, dynamic> json) => _$AttemptResultFromJson(json);

@override final  String id;
@override final  String passageId;
@override final  DateTime at;
@override final  int overall;
@override final  int accuracy;
@override final  int fluency;
 final  List<WordResult> _words;
@override List<WordResult> get words {
  if (_words is EqualUnmodifiableListView) return _words;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_words);
}

@override final  String? audioPath;
@override@JsonKey() final  ModelTier tier;

/// Create a copy of AttemptResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AttemptResultCopyWith<_AttemptResult> get copyWith => __$AttemptResultCopyWithImpl<_AttemptResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AttemptResultToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AttemptResult&&(identical(other.id, id) || other.id == id)&&(identical(other.passageId, passageId) || other.passageId == passageId)&&(identical(other.at, at) || other.at == at)&&(identical(other.overall, overall) || other.overall == overall)&&(identical(other.accuracy, accuracy) || other.accuracy == accuracy)&&(identical(other.fluency, fluency) || other.fluency == fluency)&&const DeepCollectionEquality().equals(other.words, _words)&&(identical(other.audioPath, audioPath) || other.audioPath == audioPath)&&(identical(other.tier, tier) || other.tier == tier));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,passageId,at,overall,accuracy,fluency,const DeepCollectionEquality().hash(_words),audioPath,tier);
}

@override
String toString() {
    return 'AttemptResult(id: $id, passageId: $passageId, at: $at, overall: $overall, accuracy: $accuracy, fluency: $fluency, words: $words, audioPath: $audioPath, tier: $tier)';
}


}

/// @nodoc
abstract mixin class _$AttemptResultCopyWith<$Res> implements $AttemptResultCopyWith<$Res> {
  factory _$AttemptResultCopyWith(_AttemptResult value, $Res Function(_AttemptResult) _then) = __$AttemptResultCopyWithImpl;
@override @useResult
$Res call({
 String id, String passageId, DateTime at, int overall, int accuracy, int fluency, List<WordResult> words, String? audioPath, ModelTier tier
});




}
/// @nodoc
class __$AttemptResultCopyWithImpl<$Res>
    implements _$AttemptResultCopyWith<$Res> {
  __$AttemptResultCopyWithImpl(this._self, this._then);

  final _AttemptResult _self;
  final $Res Function(_AttemptResult) _then;

/// Create a copy of AttemptResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? passageId = null,Object? at = null,Object? overall = null,Object? accuracy = null,Object? fluency = null,Object? words = null,Object? audioPath = freezed,Object? tier = null,}) {
  return _then(_AttemptResult(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,passageId: null == passageId ? _self.passageId : passageId // ignore: cast_nullable_to_non_nullable
as String,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,overall: null == overall ? _self.overall : overall // ignore: cast_nullable_to_non_nullable
as int,accuracy: null == accuracy ? _self.accuracy : accuracy // ignore: cast_nullable_to_non_nullable
as int,fluency: null == fluency ? _self.fluency : fluency // ignore: cast_nullable_to_non_nullable
as int,words: null == words ? _self._words : words // ignore: cast_nullable_to_non_nullable
as List<WordResult>,audioPath: freezed == audioPath ? _self.audioPath : audioPath // ignore: cast_nullable_to_non_nullable
as String?,tier: null == tier ? _self.tier : tier // ignore: cast_nullable_to_non_nullable
as ModelTier,
  ));
}


}

// dart format on
