// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'passage.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Passage {

 String get id; int get level; String get title; String get text; List<WordSpec> get words; List<String> get soundTags;
/// Create a copy of Passage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PassageCopyWith<Passage> get copyWith => _$PassageCopyWithImpl<Passage>(this as Passage, _$identity);

  /// Serializes this Passage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Passage;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Passage&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.level, _this.level) || other.level == _this.level)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.text, _this.text) || other.text == _this.text)&&const DeepCollectionEquality().equals(other.words, _this.words)&&const DeepCollectionEquality().equals(other.soundTags, _this.soundTags));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Passage;
  return Object.hash(runtimeType,_this.id,_this.level,_this.title,_this.text,const DeepCollectionEquality().hash(_this.words),const DeepCollectionEquality().hash(_this.soundTags));
}

@override
String toString() {
  final _this = this as Passage;
  return 'Passage(id: ${_this.id}, level: ${_this.level}, title: ${_this.title}, text: ${_this.text}, words: ${_this.words}, soundTags: ${_this.soundTags})';
}


}

/// @nodoc
abstract mixin class $PassageCopyWith<$Res>  {
  factory $PassageCopyWith(Passage value, $Res Function(Passage) _then) = _$PassageCopyWithImpl;
@useResult
$Res call({
 String id, int level, String title, String text, List<WordSpec> words, List<String> soundTags
});




}
/// @nodoc
class _$PassageCopyWithImpl<$Res>
    implements $PassageCopyWith<$Res> {
  _$PassageCopyWithImpl(this._self, this._then);

  final Passage _self;
  final $Res Function(Passage) _then;

/// Create a copy of Passage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? level = null,Object? title = null,Object? text = null,Object? words = null,Object? soundTags = null,}) {
  return _then(Passage(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,words: null == words ? _self.words : words // ignore: cast_nullable_to_non_nullable
as List<WordSpec>,soundTags: null == soundTags ? _self.soundTags : soundTags // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [Passage].
extension PassagePatterns on Passage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Passage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Passage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Passage value)  $default,){
final _that = this;
switch (_that) {
case _Passage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Passage value)?  $default,){
final _that = this;
switch (_that) {
case _Passage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  int level,  String title,  String text,  List<WordSpec> words,  List<String> soundTags)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Passage() when $default != null:
return $default(_that.id,_that.level,_that.title,_that.text,_that.words,_that.soundTags);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  int level,  String title,  String text,  List<WordSpec> words,  List<String> soundTags)  $default,) {final _that = this;
switch (_that) {
case _Passage():
return $default(_that.id,_that.level,_that.title,_that.text,_that.words,_that.soundTags);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  int level,  String title,  String text,  List<WordSpec> words,  List<String> soundTags)?  $default,) {final _that = this;
switch (_that) {
case _Passage() when $default != null:
return $default(_that.id,_that.level,_that.title,_that.text,_that.words,_that.soundTags);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Passage extends Passage {
  const _Passage({required this.id, required this.level, required this.title, required this.text, required  List<WordSpec> words,  List<String> soundTags = const <String>[]}): _words = words,_soundTags = soundTags,super._();
  factory _Passage.fromJson(Map<String, dynamic> json) => _$PassageFromJson(json);

@override final  String id;
@override final  int level;
@override final  String title;
@override final  String text;
 final  List<WordSpec> _words;
@override List<WordSpec> get words {
  if (_words is EqualUnmodifiableListView) return _words;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_words);
}

 final  List<String> _soundTags;
@override@JsonKey() List<String> get soundTags {
  if (_soundTags is EqualUnmodifiableListView) return _soundTags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_soundTags);
}


/// Create a copy of Passage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PassageCopyWith<_Passage> get copyWith => __$PassageCopyWithImpl<_Passage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PassageToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Passage&&(identical(other.id, id) || other.id == id)&&(identical(other.level, level) || other.level == level)&&(identical(other.title, title) || other.title == title)&&(identical(other.text, text) || other.text == text)&&const DeepCollectionEquality().equals(other.words, _words)&&const DeepCollectionEquality().equals(other.soundTags, _soundTags));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,level,title,text,const DeepCollectionEquality().hash(_words),const DeepCollectionEquality().hash(_soundTags));
}

@override
String toString() {
    return 'Passage(id: $id, level: $level, title: $title, text: $text, words: $words, soundTags: $soundTags)';
}


}

/// @nodoc
abstract mixin class _$PassageCopyWith<$Res> implements $PassageCopyWith<$Res> {
  factory _$PassageCopyWith(_Passage value, $Res Function(_Passage) _then) = __$PassageCopyWithImpl;
@override @useResult
$Res call({
 String id, int level, String title, String text, List<WordSpec> words, List<String> soundTags
});




}
/// @nodoc
class __$PassageCopyWithImpl<$Res>
    implements _$PassageCopyWith<$Res> {
  __$PassageCopyWithImpl(this._self, this._then);

  final _Passage _self;
  final $Res Function(_Passage) _then;

/// Create a copy of Passage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? level = null,Object? title = null,Object? text = null,Object? words = null,Object? soundTags = null,}) {
  return _then(_Passage(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,words: null == words ? _self._words : words // ignore: cast_nullable_to_non_nullable
as List<WordSpec>,soundTags: null == soundTags ? _self._soundTags : soundTags // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
