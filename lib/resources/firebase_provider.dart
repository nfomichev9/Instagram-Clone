import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:instagram_clone/models/comment.dart';
import 'package:instagram_clone/models/like.dart';
import 'package:instagram_clone/models/post.dart';
import 'package:instagram_clone/models/user.dart';

class FirebaseProvider {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Firestore _firestore = Firestore.instance;
  User user;
  Post post;
  Like like;
  Comment comment;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  StorageReference _storageReference;

  Future<void> addDataToDb(FirebaseUser currentUser) async {
    print("Inside addDataToDb Method");

    _firestore
        .collection("display_names")
        .document(currentUser.displayName)
        .setData({'displayName': currentUser.displayName});

    user = User(
        uid: currentUser.uid,
        email: currentUser.email,
        displayName: currentUser.displayName,
        photoUrl: currentUser.photoUrl,
        followers: '0',
        following: '0',
        bio: '',
        posts: '0');

    //  Map<String, String> mapdata = Map<String, dynamic>();

    //  mapdata = user.toMap(user);

    return _firestore
        .collection("users")
        .document(currentUser.uid)
        .setData(user.toMap(user));
  }

  Future<bool> authenticateUser(FirebaseUser user) async {
    print("Inside authenticateUser");
    final QuerySnapshot result = await _firestore
        .collection("users")
        .where("email", isEqualTo: user.email)
        .getDocuments();

    final List<DocumentSnapshot> docs = result.documents;

    if (docs.length == 0) {
      return true;
    } else {
      return false;
    }
  }

  Future<FirebaseUser> getCurrentUser() async {
    FirebaseUser currentUser;
    currentUser = await _auth.currentUser();
    print("EMAIL ID : ${currentUser.email}");
    return currentUser;
  }

  Future<void> signOut() async {
    await _googleSignIn.disconnect();
    await _googleSignIn.signOut();
    return await _auth.signOut();
  }

  Future<FirebaseUser> signIn() async {
    GoogleSignInAccount _signInAccount = await _googleSignIn.signIn();
    GoogleSignInAuthentication _signInAuthentication =
        await _signInAccount.authentication;

    final AuthCredential credential = GoogleAuthProvider.getCredential(
      accessToken: _signInAuthentication.accessToken,
      idToken: _signInAuthentication.idToken,
    );

    final FirebaseUser user = await _auth.signInWithCredential(credential);
    return user;
  }

  Future<String> uploadImageToStorage(File imageFile) async {
    _storageReference = FirebaseStorage.instance
        .ref()
        .child('${DateTime.now().millisecondsSinceEpoch}');
    StorageUploadTask storageUploadTask = _storageReference.putFile(imageFile);
    var url = await (await storageUploadTask.onComplete).ref.getDownloadURL();
    return url;
  }

  Future<void> addPostToDb(FirebaseUser currentUser, String imgUrl,
      String caption, String location) {
    CollectionReference _collectionRef = _firestore
        .collection("users")
        .document(currentUser.uid)
        .collection("posts");

    post = Post(
        currentUserUid: currentUser.uid,
        imgUrl: imgUrl,
        caption: caption,
        location: location,
        postOwnerName: currentUser.displayName,
        postOwnerPhotoUrl: currentUser.photoUrl,
        time: FieldValue.serverTimestamp());

    comment = Comment();
    like = Like();

    return _collectionRef.add(post.toMap(post)).then((documentReference) {
      documentReference
          .collection("comments")
          .document(currentUser.uid)
          .setData(comment.toMap(comment));
      documentReference
          .collection("likes")
          .document(currentUser.uid)
          .setData(like.toMap(like));
    });
  }

  Future<User> retrieveUserDetails(FirebaseUser user) async {
    DocumentSnapshot _documentSnapshot =
        await _firestore.collection("users").document(user.uid).get();
    return User.fromMap(_documentSnapshot.data);
  }

  Future<List<DocumentSnapshot>> retrieveUserPosts(String userId) async {
    QuerySnapshot querySnapshot = await _firestore
        .collection("users")
        .document(userId)
        .collection("posts")
        .getDocuments();
    return querySnapshot.documents;
  }

  Future<List<DocumentSnapshot>> fetchPostCommentDetails(
      DocumentReference reference) async {
    QuerySnapshot snapshot =
        await reference.collection("comments").getDocuments();
    return snapshot.documents;
  }

  Future<List<DocumentSnapshot>> fetchPostLikeDetails(
      DocumentReference reference) async {
    print("REFERENCE : ${reference.path}");
    QuerySnapshot snapshot = await reference.collection("likes").getDocuments();
    return snapshot.documents;
  }

  Future<bool> checkIfUserLikedOrNot(
      String userId, DocumentReference reference) async {
    DocumentSnapshot snapshot =
        await reference.collection("likes").document(userId).get();
    print('DOC ID : ${snapshot.reference.path}');
    return snapshot.exists;
  }

  Future<List<DocumentSnapshot>> retrievePosts(FirebaseUser user) async {
    List<DocumentSnapshot> list = List<DocumentSnapshot>();
    List<DocumentSnapshot> updatedList = List<DocumentSnapshot>();
    QuerySnapshot querySnapshot;
    QuerySnapshot snapshot =
        await _firestore.collection("users").getDocuments();
    for (int i = 0; i < snapshot.documents.length; i++) {
      if (snapshot.documents[i].documentID != user.uid) {
        list.add(snapshot.documents[i]);
      }
    }
    for (var i = 0; i < list.length; i++) {
      querySnapshot =
          await list[i].reference.collection("posts").getDocuments();
      for (var i = 0; i < querySnapshot.documents.length; i++) {
        updatedList.add(querySnapshot.documents[i]);
      }
    }
    // fetchSearchPosts(updatedList);
    print("UPDATED LIST LENGTH : ${updatedList.length}");
    return updatedList;
  }

  Future<List<String>> fetchAllUserNames(FirebaseUser user) async {
    List<String> userNameList = List<String>();
    QuerySnapshot querySnapshot =
        await _firestore.collection("users").getDocuments();
    for (var i = 0; i < querySnapshot.documents.length; i++) {
      if (querySnapshot.documents[i].documentID != user.uid) {
        userNameList.add(querySnapshot.documents[i].data['displayName']);
      }
    }
    print("USERNAMES LIST : ${userNameList.length}");
    return userNameList;
  }

  Future<String> fetchUidBySearchedName(String name) async {
    String uid;
    List<DocumentSnapshot> uidList = List<DocumentSnapshot>();

    QuerySnapshot querySnapshot =
        await _firestore.collection("users").getDocuments();
    for (var i = 0; i < querySnapshot.documents.length; i++) {
      uidList.add(querySnapshot.documents[i]);
    }

    print("UID LIST : ${uidList.length}");

    for (var i = 0; i < uidList.length; i++) {
      if (uidList[i].data['displayName'] == name) {
        uid = uidList[i].documentID;
      }
    }
    print("UID DOC ID: ${uid}");
    return uid;
  }

  Future<User> fetchUserDetailsById(String uid) async {
    DocumentSnapshot documentSnapshot =
        await _firestore.collection("users").document(uid).get();
    return User.fromMap(documentSnapshot.data);
  }

  Future<void> followUser(
      {String currentUserId, String followingUserId}) async {
    var followingMap = Map<String, String>();
    followingMap['uid'] = followingUserId;
    await _firestore
        .collection("users")
        .document(currentUserId)
        .collection("following")
        .document(followingUserId)
        .setData(followingMap);

    var followersMap = Map<String, String>();
    followersMap['uid'] = currentUserId;

    return _firestore
        .collection("users")
        .document(followingUserId)
        .collection("followers")
        .document(currentUserId)
        .setData(followersMap);
  }

  Future<void> unFollowUser(
      {String currentUserId, String followingUserId}) async {

    await _firestore
        .collection("users")
        .document(currentUserId)
        .collection("following")
        .document(followingUserId)
        .delete();



    return _firestore
        .collection("users")
        .document(followingUserId)
        .collection("followers")
        .document(currentUserId)
        .delete();
  }

 Future<bool> checkIsFollowing(String name, String currentUserId) async {
    bool isFollowing = false;
    String uid = await fetchUidBySearchedName(name);
    QuerySnapshot querySnapshot = await _firestore
        .collection("users")
        .document(currentUserId)
        .collection("following")
        .getDocuments();

    for (var i = 0; i < querySnapshot.documents.length; i++) {
      if (querySnapshot.documents[i].documentID == uid) {
        isFollowing = true;
      }
    }
    return isFollowing;
  }

  Future<List<DocumentSnapshot>> fetchStats({String uid, String label}) async {
   
   QuerySnapshot querySnapshot = await _firestore.collection("users")
              .document(uid)
              .collection(label)
              .getDocuments();
    return querySnapshot.documents;          
  }

}
