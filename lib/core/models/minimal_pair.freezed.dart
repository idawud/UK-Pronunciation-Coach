// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'minimal_pair.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MinimalPair {

 String get contrast; String get wordA; String get wordB; List<PhonemeSpec> get phonemesA; List<PhonemeSpec> get phonemesB;
/// Create a copy of MinimalPair
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MinimalPairCopyWith<MinimalPair> get copyWith => _$MinimalPairCopyWithImpl<MinimalPair>(this as MinimalPair, _$identity);

  /// Serializes this MinimalPair to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MinimalPair;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MinimalPair&&(identical(other.contrast, _this.contrast) || other.contrast == _this.contrast)&&(identical(other.wordA, _this.wordA) || other.wordA == _this.wordA)&&(identical(other.wordB, _this.wordB) || other.wordB == _this.wordB)&&const DeepCollectionEquality().equals(other.phonemesA, _this.phonemesA)&&const DeepCollectionEquality().equals(other.phonemesB, _this.phonemesB));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MinimalPair;
  return Object.hash(runtimeType,_this.contrast,_this.wordA,_this.wordB,const DeepCollectionEquality().hash(_this.phonemesA),const DeepCollectionEquality().hash(_this.phonemesB));
}

@override
String toString() {
  final _this = this as MinimalPair;
  return 'MinimalPair(contrast: ${_this.contrast}, wordA: ${_this.wordA}, wordB: ${_this.wordB}, phonemesA: ${_this.phonemesA}, phonemesB: ${_this.phonemesB})';
}


}

/// @nodoc
abstract mixin class $MinimalPairCopyWith<$Res>  {
  factory $MinimalPairCopyWith(MinimalPair value, $Res Function(MinimalPair) _then) = _$MinimalPairCopyWithImpl;
@useResult
$Res call({
 String contrast, String wordA, String wordB, List<PhonemeSpec> phonemesA, List<PhonemeSpec> phonemesB
});




}
/// @nodoc
class _$MinimalPairCopyWithImpl<$Res>
    implements $MinimalPairCopyWith<$Res> {
  _$MinimalPairCopyWithImpl(this._self, this._then);

  final MinimalPair _self;
  final $Res Function(MinimalPair) _then;

/// Create a copy of MinimalPair
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? contrast = null,Object? wordA = null,Object? wordB = null,Object? phonemesA = null,Object? phonemesB = null,}) {
  return _then(MinimalPair(
contrast: null == contrast ? _self.contrast : contrast // ignore: cast_nullable_to_non_nullable
as String,wordA: null == wordA ? _self.wordA : wordA // ignore: cast_nullable_to_non_nullable
as String,wordB: null == wordB ? _self.wordB : wordB // ignore: cast_nullable_to_non_nullable
as String,phonemesA: null == phonemesA ? _self.phonemesA : phonemesA // ignore: cast_nullable_to_non_nullable
as List<PhonemeSpec>,phonemesB: null == phonemesB ? _self.phonemesB : phonemesB // ignore: cast_nullable_to_non_nullable
as List<PhonemeSpec>,
  ));
}

}


/// Adds pattern-matching-related methods to [MinimalPair].
extension MinimalPairPatterns on MinimalPair {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MinimalPair value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MinimalPair() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MinimalPair value)  $default,){
final _that = this;
switch (_that) {
case _MinimalPair():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MinimalPair value)?  $default,){
final _that = this;
switch (_that) {
case _MinimalPair() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String contrast,  String wordA,  String wordB,  List<PhonemeSpec> phonemesA,  List<PhonemeSpec> phonemesB)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MinimalPair() when $default != null:
return $default(_that.contrast,_that.wordA,_that.wordB,_that.phonemesA,_that.phonemesB);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String contrast,  String wordA,  String wordB,  List<PhonemeSpec> phonemesA,  List<PhonemeSpec> phonemesB)  $default,) {final _that = this;
switch (_that) {
case _MinimalPair():
return $default(_that.contrast,_that.wordA,_that.wordB,_that.phonemesA,_that.phonemesB);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String contrast,  String wordA,  String wordB,  List<PhonemeSpec> phonemesA,  List<PhonemeSpec> phonemesB)?  $default,) {final _that = this;
switch (_that) {
case _MinimalPair() when $default != null:
return $default(_that.contrast,_that.wordA,_that.wordB,_that.phonemesA,_that.phonemesB);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MinimalPair implements MinimalPair {
  const _MinimalPair({required this.contrast, required this.wordA, required this.wordB,  List<PhonemeSpec> phonemesA = const <PhonemeSpec>[],  List<PhonemeSpec> phonemesB = const <PhonemeSpec>[]}): _phonemesA = phonemesA,_phonemesB = phonemesB;
  factory _MinimalPair.fromJson(Map<String, dynamic> json) => _$MinimalPairFromJson(json);

@override final  String contrast;
@override final  String wordA;
@override final  String wordB;
 final  List<PhonemeSpec> _phonemesA;
@override@JsonKey() List<PhonemeSpec> get phonemesA {
  if (_phonemesA is EqualUnmodifiableListView) return _phonemesA;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_phonemesA);
}

 final  List<PhonemeSpec> _phonemesB;
@override@JsonKey() List<PhonemeSpec> get phonemesB {
  if (_phonemesB is EqualUnmodifiableListView) return _phonemesB;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_phonemesB);
}


/// Create a copy of MinimalPair
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MinimalPairCopyWith<_MinimalPair> get copyWith => __$MinimalPairCopyWithImpl<_MinimalPair>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MinimalPairToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MinimalPair&&(identical(other.contrast, contrast) || other.contrast == contrast)&&(identical(other.wordA, wordA) || other.wordA == wordA)&&(identical(other.wordB, wordB) || other.wordB == wordB)&&const DeepCollectionEquality().equals(other.phonemesA, _phonemesA)&&const DeepCollectionEquality().equals(other.phonemesB, _phonemesB));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,contrast,wordA,wordB,const DeepCollectionEquality().hash(_phonemesA),const DeepCollectionEquality().hash(_phonemesB));
}

@override
String toString() {
    return 'MinimalPair(contrast: $contrast, wordA: $wordA, wordB: $wordB, phonemesA: $phonemesA, phonemesB: $phonemesB)';
}


}

/// @nodoc
abstract mixin class _$MinimalPairCopyWith<$Res> implements $MinimalPairCopyWith<$Res> {
  factory _$MinimalPairCopyWith(_MinimalPair value, $Res Function(_MinimalPair) _then) = __$MinimalPairCopyWithImpl;
@override @useResult
$Res call({
 String contrast, String wordA, String wordB, List<PhonemeSpec> phonemesA, List<PhonemeSpec> phonemesB
});




}
/// @nodoc
class __$MinimalPairCopyWithImpl<$Res>
    implements _$MinimalPairCopyWith<$Res> {
  __$MinimalPairCopyWithImpl(this._self, this._then);

  final _MinimalPair _self;
  final $Res Function(_MinimalPair) _then;

/// Create a copy of MinimalPair
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? contrast = null,Object? wordA = null,Object? wordB = null,Object? phonemesA = null,Object? phonemesB = null,}) {
  return _then(_MinimalPair(
contrast: null == contrast ? _self.contrast : contrast // ignore: cast_nullable_to_non_nullable
as String,wordA: null == wordA ? _self.wordA : wordA // ignore: cast_nullable_to_non_nullable
as String,wordB: null == wordB ? _self.wordB : wordB // ignore: cast_nullable_to_non_nullable
as String,phonemesA: null == phonemesA ? _self._phonemesA : phonemesA // ignore: cast_nullable_to_non_nullable
as List<PhonemeSpec>,phonemesB: null == phonemesB ? _self._phonemesB : phonemesB // ignore: cast_nullable_to_non_nullable
as List<PhonemeSpec>,
  ));
}


}

// dart format on
