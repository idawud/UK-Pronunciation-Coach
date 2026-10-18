// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'phoneme_spec.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PhonemeSpec {

 String get ipa; int get stress;
/// Create a copy of PhonemeSpec
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PhonemeSpecCopyWith<PhonemeSpec> get copyWith => _$PhonemeSpecCopyWithImpl<PhonemeSpec>(this as PhonemeSpec, _$identity);

  /// Serializes this PhonemeSpec to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PhonemeSpec;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PhonemeSpec&&(identical(other.ipa, _this.ipa) || other.ipa == _this.ipa)&&(identical(other.stress, _this.stress) || other.stress == _this.stress));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PhonemeSpec;
  return Object.hash(runtimeType,_this.ipa,_this.stress);
}

@override
String toString() {
  final _this = this as PhonemeSpec;
  return 'PhonemeSpec(ipa: ${_this.ipa}, stress: ${_this.stress})';
}


}

/// @nodoc
abstract mixin class $PhonemeSpecCopyWith<$Res>  {
  factory $PhonemeSpecCopyWith(PhonemeSpec value, $Res Function(PhonemeSpec) _then) = _$PhonemeSpecCopyWithImpl;
@useResult
$Res call({
 String ipa, int stress
});




}
/// @nodoc
class _$PhonemeSpecCopyWithImpl<$Res>
    implements $PhonemeSpecCopyWith<$Res> {
  _$PhonemeSpecCopyWithImpl(this._self, this._then);

  final PhonemeSpec _self;
  final $Res Function(PhonemeSpec) _then;

/// Create a copy of PhonemeSpec
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ipa = null,Object? stress = null,}) {
  return _then(PhonemeSpec(
ipa: null == ipa ? _self.ipa : ipa // ignore: cast_nullable_to_non_nullable
as String,stress: null == stress ? _self.stress : stress // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [PhonemeSpec].
extension PhonemeSpecPatterns on PhonemeSpec {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PhonemeSpec value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PhonemeSpec() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PhonemeSpec value)  $default,){
final _that = this;
switch (_that) {
case _PhonemeSpec():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PhonemeSpec value)?  $default,){
final _that = this;
switch (_that) {
case _PhonemeSpec() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String ipa,  int stress)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PhonemeSpec() when $default != null:
return $default(_that.ipa,_that.stress);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String ipa,  int stress)  $default,) {final _that = this;
switch (_that) {
case _PhonemeSpec():
return $default(_that.ipa,_that.stress);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String ipa,  int stress)?  $default,) {final _that = this;
switch (_that) {
case _PhonemeSpec() when $default != null:
return $default(_that.ipa,_that.stress);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PhonemeSpec implements PhonemeSpec {
  const _PhonemeSpec({required this.ipa, this.stress = 0});
  factory _PhonemeSpec.fromJson(Map<String, dynamic> json) => _$PhonemeSpecFromJson(json);

@override final  String ipa;
@override@JsonKey() final  int stress;

/// Create a copy of PhonemeSpec
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PhonemeSpecCopyWith<_PhonemeSpec> get copyWith => __$PhonemeSpecCopyWithImpl<_PhonemeSpec>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PhonemeSpecToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PhonemeSpec&&(identical(other.ipa, ipa) || other.ipa == ipa)&&(identical(other.stress, stress) || other.stress == stress));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,ipa,stress);
}

@override
String toString() {
    return 'PhonemeSpec(ipa: $ipa, stress: $stress)';
}


}

/// @nodoc
abstract mixin class _$PhonemeSpecCopyWith<$Res> implements $PhonemeSpecCopyWith<$Res> {
  factory _$PhonemeSpecCopyWith(_PhonemeSpec value, $Res Function(_PhonemeSpec) _then) = __$PhonemeSpecCopyWithImpl;
@override @useResult
$Res call({
 String ipa, int stress
});




}
/// @nodoc
class __$PhonemeSpecCopyWithImpl<$Res>
    implements _$PhonemeSpecCopyWith<$Res> {
  __$PhonemeSpecCopyWithImpl(this._self, this._then);

  final _PhonemeSpec _self;
  final $Res Function(_PhonemeSpec) _then;

/// Create a copy of PhonemeSpec
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ipa = null,Object? stress = null,}) {
  return _then(_PhonemeSpec(
ipa: null == ipa ? _self.ipa : ipa // ignore: cast_nullable_to_non_nullable
as String,stress: null == stress ? _self.stress : stress // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
