// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'phoneme_posteriors.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PhonemePosteriors {

 List<String> get vocab;@Float32ListListConverter() List<Float32List> get frames; int get blankIndex; int get frameMs; ModelTier get tier;
/// Create a copy of PhonemePosteriors
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PhonemePosteriorsCopyWith<PhonemePosteriors> get copyWith => _$PhonemePosteriorsCopyWithImpl<PhonemePosteriors>(this as PhonemePosteriors, _$identity);

  /// Serializes this PhonemePosteriors to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PhonemePosteriors;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PhonemePosteriors&&const DeepCollectionEquality().equals(other.vocab, _this.vocab)&&const DeepCollectionEquality().equals(other.frames, _this.frames)&&(identical(other.blankIndex, _this.blankIndex) || other.blankIndex == _this.blankIndex)&&(identical(other.frameMs, _this.frameMs) || other.frameMs == _this.frameMs)&&(identical(other.tier, _this.tier) || other.tier == _this.tier));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PhonemePosteriors;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.vocab),const DeepCollectionEquality().hash(_this.frames),_this.blankIndex,_this.frameMs,_this.tier);
}

@override
String toString() {
  final _this = this as PhonemePosteriors;
  return 'PhonemePosteriors(vocab: ${_this.vocab}, frames: ${_this.frames}, blankIndex: ${_this.blankIndex}, frameMs: ${_this.frameMs}, tier: ${_this.tier})';
}


}

/// @nodoc
abstract mixin class $PhonemePosteriorsCopyWith<$Res>  {
  factory $PhonemePosteriorsCopyWith(PhonemePosteriors value, $Res Function(PhonemePosteriors) _then) = _$PhonemePosteriorsCopyWithImpl;
@useResult
$Res call({
 List<String> vocab,@Float32ListListConverter() List<Float32List> frames, int blankIndex, int frameMs, ModelTier tier
});




}
/// @nodoc
class _$PhonemePosteriorsCopyWithImpl<$Res>
    implements $PhonemePosteriorsCopyWith<$Res> {
  _$PhonemePosteriorsCopyWithImpl(this._self, this._then);

  final PhonemePosteriors _self;
  final $Res Function(PhonemePosteriors) _then;

/// Create a copy of PhonemePosteriors
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? vocab = null,Object? frames = null,Object? blankIndex = null,Object? frameMs = null,Object? tier = null,}) {
  return _then(PhonemePosteriors(
vocab: null == vocab ? _self.vocab : vocab // ignore: cast_nullable_to_non_nullable
as List<String>,frames: null == frames ? _self.frames : frames // ignore: cast_nullable_to_non_nullable
as List<Float32List>,blankIndex: null == blankIndex ? _self.blankIndex : blankIndex // ignore: cast_nullable_to_non_nullable
as int,frameMs: null == frameMs ? _self.frameMs : frameMs // ignore: cast_nullable_to_non_nullable
as int,tier: null == tier ? _self.tier : tier // ignore: cast_nullable_to_non_nullable
as ModelTier,
  ));
}

}


/// Adds pattern-matching-related methods to [PhonemePosteriors].
extension PhonemePosteriorsPatterns on PhonemePosteriors {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PhonemePosteriors value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PhonemePosteriors() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PhonemePosteriors value)  $default,){
final _that = this;
switch (_that) {
case _PhonemePosteriors():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PhonemePosteriors value)?  $default,){
final _that = this;
switch (_that) {
case _PhonemePosteriors() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<String> vocab, @Float32ListListConverter()  List<Float32List> frames,  int blankIndex,  int frameMs,  ModelTier tier)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PhonemePosteriors() when $default != null:
return $default(_that.vocab,_that.frames,_that.blankIndex,_that.frameMs,_that.tier);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<String> vocab, @Float32ListListConverter()  List<Float32List> frames,  int blankIndex,  int frameMs,  ModelTier tier)  $default,) {final _that = this;
switch (_that) {
case _PhonemePosteriors():
return $default(_that.vocab,_that.frames,_that.blankIndex,_that.frameMs,_that.tier);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<String> vocab, @Float32ListListConverter()  List<Float32List> frames,  int blankIndex,  int frameMs,  ModelTier tier)?  $default,) {final _that = this;
switch (_that) {
case _PhonemePosteriors() when $default != null:
return $default(_that.vocab,_that.frames,_that.blankIndex,_that.frameMs,_that.tier);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PhonemePosteriors extends PhonemePosteriors {
  const _PhonemePosteriors({required  List<String> vocab, @Float32ListListConverter() required  List<Float32List> frames, this.blankIndex = 0, this.frameMs = 20, this.tier = ModelTier.full}): _vocab = vocab,_frames = frames,super._();
  factory _PhonemePosteriors.fromJson(Map<String, dynamic> json) => _$PhonemePosteriorsFromJson(json);

 final  List<String> _vocab;
@override List<String> get vocab {
  if (_vocab is EqualUnmodifiableListView) return _vocab;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_vocab);
}

 final  List<Float32List> _frames;
@override@Float32ListListConverter() List<Float32List> get frames {
  if (_frames is EqualUnmodifiableListView) return _frames;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_frames);
}

@override@JsonKey() final  int blankIndex;
@override@JsonKey() final  int frameMs;
@override@JsonKey() final  ModelTier tier;

/// Create a copy of PhonemePosteriors
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PhonemePosteriorsCopyWith<_PhonemePosteriors> get copyWith => __$PhonemePosteriorsCopyWithImpl<_PhonemePosteriors>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PhonemePosteriorsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PhonemePosteriors&&const DeepCollectionEquality().equals(other.vocab, _vocab)&&const DeepCollectionEquality().equals(other.frames, _frames)&&(identical(other.blankIndex, blankIndex) || other.blankIndex == blankIndex)&&(identical(other.frameMs, frameMs) || other.frameMs == frameMs)&&(identical(other.tier, tier) || other.tier == tier));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_vocab),const DeepCollectionEquality().hash(_frames),blankIndex,frameMs,tier);
}

@override
String toString() {
    return 'PhonemePosteriors(vocab: $vocab, frames: $frames, blankIndex: $blankIndex, frameMs: $frameMs, tier: $tier)';
}


}

/// @nodoc
abstract mixin class _$PhonemePosteriorsCopyWith<$Res> implements $PhonemePosteriorsCopyWith<$Res> {
  factory _$PhonemePosteriorsCopyWith(_PhonemePosteriors value, $Res Function(_PhonemePosteriors) _then) = __$PhonemePosteriorsCopyWithImpl;
@override @useResult
$Res call({
 List<String> vocab,@Float32ListListConverter() List<Float32List> frames, int blankIndex, int frameMs, ModelTier tier
});




}
/// @nodoc
class __$PhonemePosteriorsCopyWithImpl<$Res>
    implements _$PhonemePosteriorsCopyWith<$Res> {
  __$PhonemePosteriorsCopyWithImpl(this._self, this._then);

  final _PhonemePosteriors _self;
  final $Res Function(_PhonemePosteriors) _then;

/// Create a copy of PhonemePosteriors
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? vocab = null,Object? frames = null,Object? blankIndex = null,Object? frameMs = null,Object? tier = null,}) {
  return _then(_PhonemePosteriors(
vocab: null == vocab ? _self._vocab : vocab // ignore: cast_nullable_to_non_nullable
as List<String>,frames: null == frames ? _self._frames : frames // ignore: cast_nullable_to_non_nullable
as List<Float32List>,blankIndex: null == blankIndex ? _self.blankIndex : blankIndex // ignore: cast_nullable_to_non_nullable
as int,frameMs: null == frameMs ? _self.frameMs : frameMs // ignore: cast_nullable_to_non_nullable
as int,tier: null == tier ? _self.tier : tier // ignore: cast_nullable_to_non_nullable
as ModelTier,
  ));
}


}

// dart format on
