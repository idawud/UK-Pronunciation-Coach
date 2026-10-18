// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'model_download_progress.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ModelDownloadProgress {

 DownloadState get state; int get receivedBytes; int get totalBytes; String? get error;
/// Create a copy of ModelDownloadProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ModelDownloadProgressCopyWith<ModelDownloadProgress> get copyWith => _$ModelDownloadProgressCopyWithImpl<ModelDownloadProgress>(this as ModelDownloadProgress, _$identity);

  /// Serializes this ModelDownloadProgress to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ModelDownloadProgress;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ModelDownloadProgress&&(identical(other.state, _this.state) || other.state == _this.state)&&(identical(other.receivedBytes, _this.receivedBytes) || other.receivedBytes == _this.receivedBytes)&&(identical(other.totalBytes, _this.totalBytes) || other.totalBytes == _this.totalBytes)&&(identical(other.error, _this.error) || other.error == _this.error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ModelDownloadProgress;
  return Object.hash(runtimeType,_this.state,_this.receivedBytes,_this.totalBytes,_this.error);
}

@override
String toString() {
  final _this = this as ModelDownloadProgress;
  return 'ModelDownloadProgress(state: ${_this.state}, receivedBytes: ${_this.receivedBytes}, totalBytes: ${_this.totalBytes}, error: ${_this.error})';
}


}

/// @nodoc
abstract mixin class $ModelDownloadProgressCopyWith<$Res>  {
  factory $ModelDownloadProgressCopyWith(ModelDownloadProgress value, $Res Function(ModelDownloadProgress) _then) = _$ModelDownloadProgressCopyWithImpl;
@useResult
$Res call({
 DownloadState state, int receivedBytes, int totalBytes, String? error
});




}
/// @nodoc
class _$ModelDownloadProgressCopyWithImpl<$Res>
    implements $ModelDownloadProgressCopyWith<$Res> {
  _$ModelDownloadProgressCopyWithImpl(this._self, this._then);

  final ModelDownloadProgress _self;
  final $Res Function(ModelDownloadProgress) _then;

/// Create a copy of ModelDownloadProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? state = null,Object? receivedBytes = null,Object? totalBytes = null,Object? error = freezed,}) {
  return _then(ModelDownloadProgress(
state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as DownloadState,receivedBytes: null == receivedBytes ? _self.receivedBytes : receivedBytes // ignore: cast_nullable_to_non_nullable
as int,totalBytes: null == totalBytes ? _self.totalBytes : totalBytes // ignore: cast_nullable_to_non_nullable
as int,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ModelDownloadProgress].
extension ModelDownloadProgressPatterns on ModelDownloadProgress {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ModelDownloadProgress value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ModelDownloadProgress() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ModelDownloadProgress value)  $default,){
final _that = this;
switch (_that) {
case _ModelDownloadProgress():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ModelDownloadProgress value)?  $default,){
final _that = this;
switch (_that) {
case _ModelDownloadProgress() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DownloadState state,  int receivedBytes,  int totalBytes,  String? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ModelDownloadProgress() when $default != null:
return $default(_that.state,_that.receivedBytes,_that.totalBytes,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DownloadState state,  int receivedBytes,  int totalBytes,  String? error)  $default,) {final _that = this;
switch (_that) {
case _ModelDownloadProgress():
return $default(_that.state,_that.receivedBytes,_that.totalBytes,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DownloadState state,  int receivedBytes,  int totalBytes,  String? error)?  $default,) {final _that = this;
switch (_that) {
case _ModelDownloadProgress() when $default != null:
return $default(_that.state,_that.receivedBytes,_that.totalBytes,_that.error);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ModelDownloadProgress extends ModelDownloadProgress {
  const _ModelDownloadProgress({required this.state, this.receivedBytes = 0, this.totalBytes = 0, this.error}): super._();
  factory _ModelDownloadProgress.fromJson(Map<String, dynamic> json) => _$ModelDownloadProgressFromJson(json);

@override final  DownloadState state;
@override@JsonKey() final  int receivedBytes;
@override@JsonKey() final  int totalBytes;
@override final  String? error;

/// Create a copy of ModelDownloadProgress
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ModelDownloadProgressCopyWith<_ModelDownloadProgress> get copyWith => __$ModelDownloadProgressCopyWithImpl<_ModelDownloadProgress>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ModelDownloadProgressToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ModelDownloadProgress&&(identical(other.state, state) || other.state == state)&&(identical(other.receivedBytes, receivedBytes) || other.receivedBytes == receivedBytes)&&(identical(other.totalBytes, totalBytes) || other.totalBytes == totalBytes)&&(identical(other.error, error) || other.error == error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,state,receivedBytes,totalBytes,error);
}

@override
String toString() {
    return 'ModelDownloadProgress(state: $state, receivedBytes: $receivedBytes, totalBytes: $totalBytes, error: $error)';
}


}

/// @nodoc
abstract mixin class _$ModelDownloadProgressCopyWith<$Res> implements $ModelDownloadProgressCopyWith<$Res> {
  factory _$ModelDownloadProgressCopyWith(_ModelDownloadProgress value, $Res Function(_ModelDownloadProgress) _then) = __$ModelDownloadProgressCopyWithImpl;
@override @useResult
$Res call({
 DownloadState state, int receivedBytes, int totalBytes, String? error
});




}
/// @nodoc
class __$ModelDownloadProgressCopyWithImpl<$Res>
    implements _$ModelDownloadProgressCopyWith<$Res> {
  __$ModelDownloadProgressCopyWithImpl(this._self, this._then);

  final _ModelDownloadProgress _self;
  final $Res Function(_ModelDownloadProgress) _then;

/// Create a copy of ModelDownloadProgress
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? state = null,Object? receivedBytes = null,Object? totalBytes = null,Object? error = freezed,}) {
  return _then(_ModelDownloadProgress(
state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as DownloadState,receivedBytes: null == receivedBytes ? _self.receivedBytes : receivedBytes // ignore: cast_nullable_to_non_nullable
as int,totalBytes: null == totalBytes ? _self.totalBytes : totalBytes // ignore: cast_nullable_to_non_nullable
as int,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
