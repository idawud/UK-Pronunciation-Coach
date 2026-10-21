// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'word_spec.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WordSpec {

 String get text; int get index; List<PhonemeSpec> get phonemes; bool get scorable; int? get offset; List<List<PhonemeSpec>> get alternatives;
/// Create a copy of WordSpec
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WordSpecCopyWith<WordSpec> get copyWith => _$WordSpecCopyWithImpl<WordSpec>(this as WordSpec, _$identity);

  /// Serializes this WordSpec to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as WordSpec;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WordSpec&&(identical(other.text, _this.text) || other.text == _this.text)&&(identical(other.index, _this.index) || other.index == _this.index)&&const DeepCollectionEquality().equals(other.phonemes, _this.phonemes)&&(identical(other.scorable, _this.scorable) || other.scorable == _this.scorable)&&(identical(other.offset, _this.offset) || other.offset == _this.offset)&&const DeepCollectionEquality().equals(other.alternatives, _this.alternatives));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as WordSpec;
  return Object.hash(runtimeType,_this.text,_this.index,const DeepCollectionEquality().hash(_this.phonemes),_this.scorable,_this.offset,const DeepCollectionEquality().hash(_this.alternatives));
}

@override
String toString() {
  final _this = this as WordSpec;
  return 'WordSpec(text: ${_this.text}, index: ${_this.index}, phonemes: ${_this.phonemes}, scorable: ${_this.scorable}, offset: ${_this.offset}, alternatives: ${_this.alternatives})';
}


}

/// @nodoc
abstract mixin class $WordSpecCopyWith<$Res>  {
  factory $WordSpecCopyWith(WordSpec value, $Res Function(WordSpec) _then) = _$WordSpecCopyWithImpl;
@useResult
$Res call({
 String text, int index, List<PhonemeSpec> phonemes, bool scorable, int? offset, List<List<PhonemeSpec>> alternatives
});




}
/// @nodoc
class _$WordSpecCopyWithImpl<$Res>
    implements $WordSpecCopyWith<$Res> {
  _$WordSpecCopyWithImpl(this._self, this._then);

  final WordSpec _self;
  final $Res Function(WordSpec) _then;

/// Create a copy of WordSpec
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? text = null,Object? index = null,Object? phonemes = null,Object? scorable = null,Object? offset = freezed,Object? alternatives = null,}) {
  return _then(WordSpec(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,phonemes: null == phonemes ? _self.phonemes : phonemes // ignore: cast_nullable_to_non_nullable
as List<PhonemeSpec>,scorable: null == scorable ? _self.scorable : scorable // ignore: cast_nullable_to_non_nullable
as bool,offset: freezed == offset ? _self.offset : offset // ignore: cast_nullable_to_non_nullable
as int?,alternatives: null == alternatives ? _self.alternatives : alternatives // ignore: cast_nullable_to_non_nullable
as List<List<PhonemeSpec>>,
  ));
}

}


/// Adds pattern-matching-related methods to [WordSpec].
extension WordSpecPatterns on WordSpec {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WordSpec value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WordSpec() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WordSpec value)  $default,){
final _that = this;
switch (_that) {
case _WordSpec():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WordSpec value)?  $default,){
final _that = this;
switch (_that) {
case _WordSpec() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String text,  int index,  List<PhonemeSpec> phonemes,  bool scorable,  int? offset,  List<List<PhonemeSpec>> alternatives)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WordSpec() when $default != null:
return $default(_that.text,_that.index,_that.phonemes,_that.scorable,_that.offset,_that.alternatives);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String text,  int index,  List<PhonemeSpec> phonemes,  bool scorable,  int? offset,  List<List<PhonemeSpec>> alternatives)  $default,) {final _that = this;
switch (_that) {
case _WordSpec():
return $default(_that.text,_that.index,_that.phonemes,_that.scorable,_that.offset,_that.alternatives);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String text,  int index,  List<PhonemeSpec> phonemes,  bool scorable,  int? offset,  List<List<PhonemeSpec>> alternatives)?  $default,) {final _that = this;
switch (_that) {
case _WordSpec() when $default != null:
return $default(_that.text,_that.index,_that.phonemes,_that.scorable,_that.offset,_that.alternatives);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WordSpec implements WordSpec {
  const _WordSpec({required this.text, required this.index,  List<PhonemeSpec> phonemes = const <PhonemeSpec>[], this.scorable = true, this.offset,  List<List<PhonemeSpec>> alternatives = const <List<PhonemeSpec>>[]}): _phonemes = phonemes,_alternatives = alternatives;
  factory _WordSpec.fromJson(Map<String, dynamic> json) => _$WordSpecFromJson(json);

@override final  String text;
@override final  int index;
 final  List<PhonemeSpec> _phonemes;
@override@JsonKey() List<PhonemeSpec> get phonemes {
  if (_phonemes is EqualUnmodifiableListView) return _phonemes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_phonemes);
}

@override@JsonKey() final  bool scorable;
@override final  int? offset;
 final  List<List<PhonemeSpec>> _alternatives;
@override@JsonKey() List<List<PhonemeSpec>> get alternatives {
  if (_alternatives is EqualUnmodifiableListView) return _alternatives;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_alternatives);
}


/// Create a copy of WordSpec
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WordSpecCopyWith<_WordSpec> get copyWith => __$WordSpecCopyWithImpl<_WordSpec>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WordSpecToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WordSpec&&(identical(other.text, text) || other.text == text)&&(identical(other.index, index) || other.index == index)&&const DeepCollectionEquality().equals(other.phonemes, _phonemes)&&(identical(other.scorable, scorable) || other.scorable == scorable)&&(identical(other.offset, offset) || other.offset == offset)&&const DeepCollectionEquality().equals(other.alternatives, _alternatives));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,text,index,const DeepCollectionEquality().hash(_phonemes),scorable,offset,const DeepCollectionEquality().hash(_alternatives));
}

@override
String toString() {
    return 'WordSpec(text: $text, index: $index, phonemes: $phonemes, scorable: $scorable, offset: $offset, alternatives: $alternatives)';
}


}

/// @nodoc
abstract mixin class _$WordSpecCopyWith<$Res> implements $WordSpecCopyWith<$Res> {
  factory _$WordSpecCopyWith(_WordSpec value, $Res Function(_WordSpec) _then) = __$WordSpecCopyWithImpl;
@override @useResult
$Res call({
 String text, int index, List<PhonemeSpec> phonemes, bool scorable, int? offset, List<List<PhonemeSpec>> alternatives
});




}
/// @nodoc
class __$WordSpecCopyWithImpl<$Res>
    implements _$WordSpecCopyWith<$Res> {
  __$WordSpecCopyWithImpl(this._self, this._then);

  final _WordSpec _self;
  final $Res Function(_WordSpec) _then;

/// Create a copy of WordSpec
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? text = null,Object? index = null,Object? phonemes = null,Object? scorable = null,Object? offset = freezed,Object? alternatives = null,}) {
  return _then(_WordSpec(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,phonemes: null == phonemes ? _self._phonemes : phonemes // ignore: cast_nullable_to_non_nullable
as List<PhonemeSpec>,scorable: null == scorable ? _self.scorable : scorable // ignore: cast_nullable_to_non_nullable
as bool,offset: freezed == offset ? _self.offset : offset // ignore: cast_nullable_to_non_nullable
as int?,alternatives: null == alternatives ? _self._alternatives : alternatives // ignore: cast_nullable_to_non_nullable
as List<List<PhonemeSpec>>,
  ));
}


}

// dart format on
