// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'audio_clip.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AudioClip {

 String get path; int get sampleRate; Duration get duration; AudioQuality get quality; double? get peakDbfs; double? get snrDb;
/// Create a copy of AudioClip
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AudioClipCopyWith<AudioClip> get copyWith => _$AudioClipCopyWithImpl<AudioClip>(this as AudioClip, _$identity);

  /// Serializes this AudioClip to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AudioClip;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AudioClip&&(identical(other.path, _this.path) || other.path == _this.path)&&(identical(other.sampleRate, _this.sampleRate) || other.sampleRate == _this.sampleRate)&&(identical(other.duration, _this.duration) || other.duration == _this.duration)&&(identical(other.quality, _this.quality) || other.quality == _this.quality)&&(identical(other.peakDbfs, _this.peakDbfs) || other.peakDbfs == _this.peakDbfs)&&(identical(other.snrDb, _this.snrDb) || other.snrDb == _this.snrDb));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AudioClip;
  return Object.hash(runtimeType,_this.path,_this.sampleRate,_this.duration,_this.quality,_this.peakDbfs,_this.snrDb);
}

@override
String toString() {
  final _this = this as AudioClip;
  return 'AudioClip(path: ${_this.path}, sampleRate: ${_this.sampleRate}, duration: ${_this.duration}, quality: ${_this.quality}, peakDbfs: ${_this.peakDbfs}, snrDb: ${_this.snrDb})';
}


}

/// @nodoc
abstract mixin class $AudioClipCopyWith<$Res>  {
  factory $AudioClipCopyWith(AudioClip value, $Res Function(AudioClip) _then) = _$AudioClipCopyWithImpl;
@useResult
$Res call({
 String path, int sampleRate, Duration duration, AudioQuality quality, double? peakDbfs, double? snrDb
});




}
/// @nodoc
class _$AudioClipCopyWithImpl<$Res>
    implements $AudioClipCopyWith<$Res> {
  _$AudioClipCopyWithImpl(this._self, this._then);

  final AudioClip _self;
  final $Res Function(AudioClip) _then;

/// Create a copy of AudioClip
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? path = null,Object? sampleRate = null,Object? duration = null,Object? quality = null,Object? peakDbfs = freezed,Object? snrDb = freezed,}) {
  return _then(AudioClip(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,sampleRate: null == sampleRate ? _self.sampleRate : sampleRate // ignore: cast_nullable_to_non_nullable
as int,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration,quality: null == quality ? _self.quality : quality // ignore: cast_nullable_to_non_nullable
as AudioQuality,peakDbfs: freezed == peakDbfs ? _self.peakDbfs : peakDbfs // ignore: cast_nullable_to_non_nullable
as double?,snrDb: freezed == snrDb ? _self.snrDb : snrDb // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [AudioClip].
extension AudioClipPatterns on AudioClip {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AudioClip value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AudioClip() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AudioClip value)  $default,){
final _that = this;
switch (_that) {
case _AudioClip():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AudioClip value)?  $default,){
final _that = this;
switch (_that) {
case _AudioClip() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String path,  int sampleRate,  Duration duration,  AudioQuality quality,  double? peakDbfs,  double? snrDb)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AudioClip() when $default != null:
return $default(_that.path,_that.sampleRate,_that.duration,_that.quality,_that.peakDbfs,_that.snrDb);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String path,  int sampleRate,  Duration duration,  AudioQuality quality,  double? peakDbfs,  double? snrDb)  $default,) {final _that = this;
switch (_that) {
case _AudioClip():
return $default(_that.path,_that.sampleRate,_that.duration,_that.quality,_that.peakDbfs,_that.snrDb);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String path,  int sampleRate,  Duration duration,  AudioQuality quality,  double? peakDbfs,  double? snrDb)?  $default,) {final _that = this;
switch (_that) {
case _AudioClip() when $default != null:
return $default(_that.path,_that.sampleRate,_that.duration,_that.quality,_that.peakDbfs,_that.snrDb);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AudioClip implements AudioClip {
  const _AudioClip({required this.path, this.sampleRate = 16000, required this.duration, this.quality = AudioQuality.ok, this.peakDbfs, this.snrDb});
  factory _AudioClip.fromJson(Map<String, dynamic> json) => _$AudioClipFromJson(json);

@override final  String path;
@override@JsonKey() final  int sampleRate;
@override final  Duration duration;
@override@JsonKey() final  AudioQuality quality;
@override final  double? peakDbfs;
@override final  double? snrDb;

/// Create a copy of AudioClip
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AudioClipCopyWith<_AudioClip> get copyWith => __$AudioClipCopyWithImpl<_AudioClip>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AudioClipToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AudioClip&&(identical(other.path, path) || other.path == path)&&(identical(other.sampleRate, sampleRate) || other.sampleRate == sampleRate)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.quality, quality) || other.quality == quality)&&(identical(other.peakDbfs, peakDbfs) || other.peakDbfs == peakDbfs)&&(identical(other.snrDb, snrDb) || other.snrDb == snrDb));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,path,sampleRate,duration,quality,peakDbfs,snrDb);
}

@override
String toString() {
    return 'AudioClip(path: $path, sampleRate: $sampleRate, duration: $duration, quality: $quality, peakDbfs: $peakDbfs, snrDb: $snrDb)';
}


}

/// @nodoc
abstract mixin class _$AudioClipCopyWith<$Res> implements $AudioClipCopyWith<$Res> {
  factory _$AudioClipCopyWith(_AudioClip value, $Res Function(_AudioClip) _then) = __$AudioClipCopyWithImpl;
@override @useResult
$Res call({
 String path, int sampleRate, Duration duration, AudioQuality quality, double? peakDbfs, double? snrDb
});




}
/// @nodoc
class __$AudioClipCopyWithImpl<$Res>
    implements _$AudioClipCopyWith<$Res> {
  __$AudioClipCopyWithImpl(this._self, this._then);

  final _AudioClip _self;
  final $Res Function(_AudioClip) _then;

/// Create a copy of AudioClip
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? path = null,Object? sampleRate = null,Object? duration = null,Object? quality = null,Object? peakDbfs = freezed,Object? snrDb = freezed,}) {
  return _then(_AudioClip(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,sampleRate: null == sampleRate ? _self.sampleRate : sampleRate // ignore: cast_nullable_to_non_nullable
as int,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration,quality: null == quality ? _self.quality : quality // ignore: cast_nullable_to_non_nullable
as AudioQuality,peakDbfs: freezed == peakDbfs ? _self.peakDbfs : peakDbfs // ignore: cast_nullable_to_non_nullable
as double?,snrDb: freezed == snrDb ? _self.snrDb : snrDb // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

// dart format on
