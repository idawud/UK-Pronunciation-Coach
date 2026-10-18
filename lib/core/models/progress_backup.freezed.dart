// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'progress_backup.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ProgressBackup {

 int get schemaVersion; DateTime get exportedAt; UserProfile get profile; List<AttemptResult> get attempts; List<SoundStat> get soundStats; List<ReviewItem> get reviewQueue; List<LevelChange> get levelHistory; List<PracticeSession> get practiceSessions;
/// Create a copy of ProgressBackup
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProgressBackupCopyWith<ProgressBackup> get copyWith => _$ProgressBackupCopyWithImpl<ProgressBackup>(this as ProgressBackup, _$identity);

  /// Serializes this ProgressBackup to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ProgressBackup;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProgressBackup&&(identical(other.schemaVersion, _this.schemaVersion) || other.schemaVersion == _this.schemaVersion)&&(identical(other.exportedAt, _this.exportedAt) || other.exportedAt == _this.exportedAt)&&(identical(other.profile, _this.profile) || other.profile == _this.profile)&&const DeepCollectionEquality().equals(other.attempts, _this.attempts)&&const DeepCollectionEquality().equals(other.soundStats, _this.soundStats)&&const DeepCollectionEquality().equals(other.reviewQueue, _this.reviewQueue)&&const DeepCollectionEquality().equals(other.levelHistory, _this.levelHistory)&&const DeepCollectionEquality().equals(other.practiceSessions, _this.practiceSessions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ProgressBackup;
  return Object.hash(runtimeType,_this.schemaVersion,_this.exportedAt,_this.profile,const DeepCollectionEquality().hash(_this.attempts),const DeepCollectionEquality().hash(_this.soundStats),const DeepCollectionEquality().hash(_this.reviewQueue),const DeepCollectionEquality().hash(_this.levelHistory),const DeepCollectionEquality().hash(_this.practiceSessions));
}

@override
String toString() {
  final _this = this as ProgressBackup;
  return 'ProgressBackup(schemaVersion: ${_this.schemaVersion}, exportedAt: ${_this.exportedAt}, profile: ${_this.profile}, attempts: ${_this.attempts}, soundStats: ${_this.soundStats}, reviewQueue: ${_this.reviewQueue}, levelHistory: ${_this.levelHistory}, practiceSessions: ${_this.practiceSessions})';
}


}

/// @nodoc
abstract mixin class $ProgressBackupCopyWith<$Res>  {
  factory $ProgressBackupCopyWith(ProgressBackup value, $Res Function(ProgressBackup) _then) = _$ProgressBackupCopyWithImpl;
@useResult
$Res call({
 int schemaVersion, DateTime exportedAt, UserProfile profile, List<AttemptResult> attempts, List<SoundStat> soundStats, List<ReviewItem> reviewQueue, List<LevelChange> levelHistory, List<PracticeSession> practiceSessions
});


$UserProfileCopyWith<$Res> get profile;

}
/// @nodoc
class _$ProgressBackupCopyWithImpl<$Res>
    implements $ProgressBackupCopyWith<$Res> {
  _$ProgressBackupCopyWithImpl(this._self, this._then);

  final ProgressBackup _self;
  final $Res Function(ProgressBackup) _then;

/// Create a copy of ProgressBackup
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? schemaVersion = null,Object? exportedAt = null,Object? profile = null,Object? attempts = null,Object? soundStats = null,Object? reviewQueue = null,Object? levelHistory = null,Object? practiceSessions = null,}) {
  return _then(ProgressBackup(
schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,exportedAt: null == exportedAt ? _self.exportedAt : exportedAt // ignore: cast_nullable_to_non_nullable
as DateTime,profile: null == profile ? _self.profile : profile // ignore: cast_nullable_to_non_nullable
as UserProfile,attempts: null == attempts ? _self.attempts : attempts // ignore: cast_nullable_to_non_nullable
as List<AttemptResult>,soundStats: null == soundStats ? _self.soundStats : soundStats // ignore: cast_nullable_to_non_nullable
as List<SoundStat>,reviewQueue: null == reviewQueue ? _self.reviewQueue : reviewQueue // ignore: cast_nullable_to_non_nullable
as List<ReviewItem>,levelHistory: null == levelHistory ? _self.levelHistory : levelHistory // ignore: cast_nullable_to_non_nullable
as List<LevelChange>,practiceSessions: null == practiceSessions ? _self.practiceSessions : practiceSessions // ignore: cast_nullable_to_non_nullable
as List<PracticeSession>,
  ));
}
/// Create a copy of ProgressBackup
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserProfileCopyWith<$Res> get profile {
  
  return $UserProfileCopyWith<$Res>(_self.profile, (value) {
    return _then(_self.copyWith(profile: value));
  });
}
}


/// Adds pattern-matching-related methods to [ProgressBackup].
extension ProgressBackupPatterns on ProgressBackup {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProgressBackup value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProgressBackup() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProgressBackup value)  $default,){
final _that = this;
switch (_that) {
case _ProgressBackup():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProgressBackup value)?  $default,){
final _that = this;
switch (_that) {
case _ProgressBackup() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int schemaVersion,  DateTime exportedAt,  UserProfile profile,  List<AttemptResult> attempts,  List<SoundStat> soundStats,  List<ReviewItem> reviewQueue,  List<LevelChange> levelHistory,  List<PracticeSession> practiceSessions)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProgressBackup() when $default != null:
return $default(_that.schemaVersion,_that.exportedAt,_that.profile,_that.attempts,_that.soundStats,_that.reviewQueue,_that.levelHistory,_that.practiceSessions);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int schemaVersion,  DateTime exportedAt,  UserProfile profile,  List<AttemptResult> attempts,  List<SoundStat> soundStats,  List<ReviewItem> reviewQueue,  List<LevelChange> levelHistory,  List<PracticeSession> practiceSessions)  $default,) {final _that = this;
switch (_that) {
case _ProgressBackup():
return $default(_that.schemaVersion,_that.exportedAt,_that.profile,_that.attempts,_that.soundStats,_that.reviewQueue,_that.levelHistory,_that.practiceSessions);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int schemaVersion,  DateTime exportedAt,  UserProfile profile,  List<AttemptResult> attempts,  List<SoundStat> soundStats,  List<ReviewItem> reviewQueue,  List<LevelChange> levelHistory,  List<PracticeSession> practiceSessions)?  $default,) {final _that = this;
switch (_that) {
case _ProgressBackup() when $default != null:
return $default(_that.schemaVersion,_that.exportedAt,_that.profile,_that.attempts,_that.soundStats,_that.reviewQueue,_that.levelHistory,_that.practiceSessions);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProgressBackup implements ProgressBackup {
  const _ProgressBackup({this.schemaVersion = ProgressBackup.currentSchemaVersion, required this.exportedAt, required this.profile,  List<AttemptResult> attempts = const <AttemptResult>[],  List<SoundStat> soundStats = const <SoundStat>[],  List<ReviewItem> reviewQueue = const <ReviewItem>[],  List<LevelChange> levelHistory = const <LevelChange>[],  List<PracticeSession> practiceSessions = const <PracticeSession>[]}): _attempts = attempts,_soundStats = soundStats,_reviewQueue = reviewQueue,_levelHistory = levelHistory,_practiceSessions = practiceSessions;
  factory _ProgressBackup.fromJson(Map<String, dynamic> json) => _$ProgressBackupFromJson(json);

@override@JsonKey() final  int schemaVersion;
@override final  DateTime exportedAt;
@override final  UserProfile profile;
 final  List<AttemptResult> _attempts;
@override@JsonKey() List<AttemptResult> get attempts {
  if (_attempts is EqualUnmodifiableListView) return _attempts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_attempts);
}

 final  List<SoundStat> _soundStats;
@override@JsonKey() List<SoundStat> get soundStats {
  if (_soundStats is EqualUnmodifiableListView) return _soundStats;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_soundStats);
}

 final  List<ReviewItem> _reviewQueue;
@override@JsonKey() List<ReviewItem> get reviewQueue {
  if (_reviewQueue is EqualUnmodifiableListView) return _reviewQueue;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_reviewQueue);
}

 final  List<LevelChange> _levelHistory;
@override@JsonKey() List<LevelChange> get levelHistory {
  if (_levelHistory is EqualUnmodifiableListView) return _levelHistory;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_levelHistory);
}

 final  List<PracticeSession> _practiceSessions;
@override@JsonKey() List<PracticeSession> get practiceSessions {
  if (_practiceSessions is EqualUnmodifiableListView) return _practiceSessions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_practiceSessions);
}


/// Create a copy of ProgressBackup
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProgressBackupCopyWith<_ProgressBackup> get copyWith => __$ProgressBackupCopyWithImpl<_ProgressBackup>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProgressBackupToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProgressBackup&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion)&&(identical(other.exportedAt, exportedAt) || other.exportedAt == exportedAt)&&(identical(other.profile, profile) || other.profile == profile)&&const DeepCollectionEquality().equals(other.attempts, _attempts)&&const DeepCollectionEquality().equals(other.soundStats, _soundStats)&&const DeepCollectionEquality().equals(other.reviewQueue, _reviewQueue)&&const DeepCollectionEquality().equals(other.levelHistory, _levelHistory)&&const DeepCollectionEquality().equals(other.practiceSessions, _practiceSessions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,schemaVersion,exportedAt,profile,const DeepCollectionEquality().hash(_attempts),const DeepCollectionEquality().hash(_soundStats),const DeepCollectionEquality().hash(_reviewQueue),const DeepCollectionEquality().hash(_levelHistory),const DeepCollectionEquality().hash(_practiceSessions));
}

@override
String toString() {
    return 'ProgressBackup(schemaVersion: $schemaVersion, exportedAt: $exportedAt, profile: $profile, attempts: $attempts, soundStats: $soundStats, reviewQueue: $reviewQueue, levelHistory: $levelHistory, practiceSessions: $practiceSessions)';
}


}

/// @nodoc
abstract mixin class _$ProgressBackupCopyWith<$Res> implements $ProgressBackupCopyWith<$Res> {
  factory _$ProgressBackupCopyWith(_ProgressBackup value, $Res Function(_ProgressBackup) _then) = __$ProgressBackupCopyWithImpl;
@override @useResult
$Res call({
 int schemaVersion, DateTime exportedAt, UserProfile profile, List<AttemptResult> attempts, List<SoundStat> soundStats, List<ReviewItem> reviewQueue, List<LevelChange> levelHistory, List<PracticeSession> practiceSessions
});


@override $UserProfileCopyWith<$Res> get profile;

}
/// @nodoc
class __$ProgressBackupCopyWithImpl<$Res>
    implements _$ProgressBackupCopyWith<$Res> {
  __$ProgressBackupCopyWithImpl(this._self, this._then);

  final _ProgressBackup _self;
  final $Res Function(_ProgressBackup) _then;

/// Create a copy of ProgressBackup
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? schemaVersion = null,Object? exportedAt = null,Object? profile = null,Object? attempts = null,Object? soundStats = null,Object? reviewQueue = null,Object? levelHistory = null,Object? practiceSessions = null,}) {
  return _then(_ProgressBackup(
schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,exportedAt: null == exportedAt ? _self.exportedAt : exportedAt // ignore: cast_nullable_to_non_nullable
as DateTime,profile: null == profile ? _self.profile : profile // ignore: cast_nullable_to_non_nullable
as UserProfile,attempts: null == attempts ? _self._attempts : attempts // ignore: cast_nullable_to_non_nullable
as List<AttemptResult>,soundStats: null == soundStats ? _self._soundStats : soundStats // ignore: cast_nullable_to_non_nullable
as List<SoundStat>,reviewQueue: null == reviewQueue ? _self._reviewQueue : reviewQueue // ignore: cast_nullable_to_non_nullable
as List<ReviewItem>,levelHistory: null == levelHistory ? _self._levelHistory : levelHistory // ignore: cast_nullable_to_non_nullable
as List<LevelChange>,practiceSessions: null == practiceSessions ? _self._practiceSessions : practiceSessions // ignore: cast_nullable_to_non_nullable
as List<PracticeSession>,
  ));
}

/// Create a copy of ProgressBackup
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserProfileCopyWith<$Res> get profile {
  
  return $UserProfileCopyWith<$Res>(_self.profile, (value) {
    return _then(_self.copyWith(profile: value));
  });
}
}

// dart format on
