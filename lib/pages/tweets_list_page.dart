import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';

import '../config/config.dart';
import '../events/login_event.dart';
import '../events/logout_event.dart';
import '../pages/new_login_page.dart';
import '../utils/utf8_utils.dart';
import '../utils/black_list_utils.dart';
import '../api/api.dart';
import '../utils/net_utils.dart';
import '../pages/tweets_detail_page.dart';
// import '../pages/login_page.dart';
import '../utils/data_utils.dart';

class TweetsListPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return TweetsListPageState();
  }
}

class TweetsListPageState extends State<TweetsListPage> {
  List hotTweetsList;
  List normalTweetsList;
  TextStyle authorTextStyle;
  TextStyle subtitleStyle;
  RegExp regExp1 = RegExp("</.*>");
  RegExp regExp2 = RegExp("<.*>");
  num curPage = 1;
  bool loading = false;
  ScrollController _controller;
  bool isUserLogin = false;

  @override
  void initState() {
    super.initState();
    DataUtils.isLogin().then((isLogin) {
      setState(() {
        this.isUserLogin = isLogin;
      });
    });
    Config.eventBus.on<LoginEvent>().listen((event) {
      setState(() {
        this.isUserLogin = true;
      });
    });
    Config.eventBus.on<LogoutEvent>().listen((event) {
      setState(() {
        this.isUserLogin = false;
      });
    });
  }

  TweetsListPageState() {
    authorTextStyle =
        TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold);
    subtitleStyle =
        TextStyle(fontSize: 12.0, color: const Color(0xFFB5BDC0));
    _controller = ScrollController();
    _controller.addListener(() {
      var maxScroll = _controller.position.maxScrollExtent;
      var pixels = _controller.position.pixels;
      if (maxScroll == pixels) {
        // load next page
        curPage++;
        getTweetsList(true, false);
      }
    });
  }

  getTweetsList(bool isLoadMore, bool isHot) {
    DataUtils.getAccessToken().then((token) {
      if (token == null || token.length == 0) {
        return;
      }
      loading = true;
      Map<String, String> params = Map();
      params['access_token'] = token;
      params['page'] = "$curPage";
      if (isHot) {
        params['user'] = "-1";
      } else {
        params['user'] = "0";
      }
      params['pageSize'] = "20";
      params['dataType'] = "json";
      NetUtils.get(Api.tweetsList, params: params).then((data) {
        Map<String, dynamic> obj = json.decode(data);
        if (!isLoadMore) {
          // first load
          if (isHot) {
            hotTweetsList = obj['tweetlist'];
          } else {
            normalTweetsList = obj['tweetlist'];
          }
        } else {
          // load more
          List list = List();
          list.addAll(normalTweetsList);
          list.addAll(obj['tweetlist']);
          normalTweetsList = list;
        }
        filterList(hotTweetsList, true);
        filterList(normalTweetsList, false);
      });
    });
  }

  // ????????????????????????????????????
  filterList(List<dynamic> objList, bool isHot) {
    BlackListUtils.getBlackListIds().then((intList) {
      if (intList != null && intList.isNotEmpty && objList != null) {
        List newList = List();
        for (dynamic item in objList) {
          int authorId = item['authorid'];
          if (!intList.contains(authorId)) {
            newList.add(item);
          }
        }
        setState(() {
          if (isHot) {
            hotTweetsList = newList;
          } else {
            normalTweetsList = newList;
          }
          loading = false;
        });
      } else {
        // ??????????????????????????????????????????
        setState(() {
          if (isHot) {
            hotTweetsList = objList;
          } else {
            normalTweetsList = objList;
          }
          loading = false;
        });
      }
    });
  }

  // ??????????????????html??????
  String clearHtmlContent(String str) {
    if (str.startsWith("<emoji")) {
      return "[emoji]";
    }
    var s = str.replaceAll(regExp1, "");
    s = s.replaceAll(regExp2, "");
    s = s.replaceAll("\n", "");
    return s;
  }

  Widget getRowWidget(Map<String, dynamic> listItem) {
    var authorRow = Row(
      children: <Widget>[
        Container(
          width: 35.0,
          height: 35.0,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.transparent,
            image: DecorationImage(
                image: NetworkImage(listItem['portrait']),
                fit: BoxFit.cover),
            border: Border.all(
              color: Colors.white,
              width: 2.0,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(6.0, 0.0, 0.0, 0.0),
          child: Text(
            listItem['author'],
            style: TextStyle(fontSize: 16.0)
          )
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              Text(
                '${listItem['commentCount']}',
                style: subtitleStyle,
              ),
              Image.asset(
                './images/ic_comment.png',
                width: 16.0,
                height: 16.0,
              )
            ],
          ),
        )
      ],
    );
    var _body = listItem['body'];
    _body = clearHtmlContent(_body);
    var contentRow = Row(
      children: <Widget>[
        Expanded(child: Text(_body))
      ],
    );
    var timeRow = Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        Text(
          listItem['pubDate'],
          style: subtitleStyle,
        )
      ],
    );
    var columns = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 2.0),
        child: authorRow,
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(52.0, 0.0, 10.0, 0.0),
        child: contentRow,
      ),
    ];
    String imgSmall = listItem['imgSmall'];
    if (imgSmall != null && imgSmall.length > 0) {
      // ??????????????????
      List<String> list = imgSmall.split(",");
      List<String> imgUrlList = List<String>();
      for (String s in list) {
        if (s.startsWith("http")) {
          imgUrlList.add(s);
        } else {
          imgUrlList.add("https://static.oschina.net/uploads/space/" + s);
        }
      }
      List<Widget> imgList = [];
      List<List<Widget>> rows = [];
      num len = imgUrlList.length;
      for (var row = 0; row < getRow(len); row++) {
        List<Widget> rowArr = [];
        for (var col = 0; col < 3; col++) {
          num index = row * 3 + col;
          num screenWidth = MediaQuery.of(context).size.width;
          double cellWidth = (screenWidth - 100) / 3;
          if (index < len) {
            rowArr.add(Padding(
              padding: const EdgeInsets.all(2.0),
              child: Image.network(imgUrlList[index],
                  width: cellWidth, height: cellWidth),
            ));
          }
        }
        rows.add(rowArr);
      }
      for (var row in rows) {
        imgList.add(Row(
          children: row,
        ));
      }
      columns.add(Padding(
        padding: const EdgeInsets.fromLTRB(52.0, 5.0, 10.0, 0.0),
        child: Column(
          children: imgList,
        ),
      ));
    }
    columns.add(Padding(
      padding: const EdgeInsets.fromLTRB(0.0, 10.0, 10.0, 6.0),
      child: timeRow,
    ));
    return InkWell(
      child: Column(
        children: columns,
      ),
      onTap: () {
        // ?????????????????????
        Navigator.of(context).push(MaterialPageRoute(builder: (ctx) {
          return TweetDetailPage(
            tweetData: listItem,
          );
        }));
      },
      onLongPress: () {
        showDialog(
          context: context,
          builder: (BuildContext ctx) {
            return AlertDialog(
              title: Text('??????'),
              content: Text('??????\"${listItem['author']}\"?????????????????????'),
              actions: <Widget>[
                FlatButton(
                  child: Text(
                    '??????',
                    style: TextStyle(color: Colors.red),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                FlatButton(
                  child: Text(
                    '??????',
                    style: TextStyle(color: Colors.blue),
                  ),
                  onPressed: () {
                    putIntoBlackHouse(listItem);
                  },
                )
              ],
            );
          });
      },
    );
  }

  // ???????????????
  putIntoBlackHouse(item) {
    int authorId = item['authorid'];
    String portrait = "${item['portrait']}";
    String nickname = "${item['author']}";
    DataUtils.getUserInfo().then((info) {
      if (info != null) {
        int loginUserId = info.id;
        Map<String, String> params = Map();
        params['userid'] = '$loginUserId';
        params['authorid'] = '$authorId';
        params['authoravatar'] = portrait;
        params['authorname'] = Utf8Utils.encode(nickname);
        NetUtils.post(Api.addToBlack, params: params).then((data) {
          Navigator.of(context).pop();
          if (data != null) {
            var obj = json.decode(data);
            if (obj['code'] == 0) {
              // ????????????????????????
              showAddBlackHouseResultDialog("???????????????????????????");
              BlackListUtils.addBlackId(authorId).then((arg) {
                // ?????????????????????????????????
                filterList(normalTweetsList, false);
                filterList(hotTweetsList, true);
              });
            } else {
              // ????????????
              var msg = obj['msg'];
              showAddBlackHouseResultDialog("???????????????????????????$msg");
            }
          }
        }).catchError((e) {
          Navigator.of(context).pop();
          showAddBlackHouseResultDialog("?????????????????????$e");
        });
      }
    });
  }

  showAddBlackHouseResultDialog(String msg) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text('??????'),
          content: Text(msg),
          actions: <Widget>[
            FlatButton(
              child: Text(
                '??????',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            )
          ],
        );
      });
  }

  renderHotRow(i) {
    if (i.isOdd) {
      return Divider(
        height: 1.0,
      );
    } else {
      i = i ~/ 2;
      return getRowWidget(hotTweetsList[i]);
    }
  }

  renderNormalRow(i) {
    if (i.isOdd) {
      return Divider(
        height: 1.0,
      );
    } else {
      i = i ~/ 2;
      return getRowWidget(normalTweetsList[i]);
    }
  }

  int getRow(int n) {
    int a = n % 3;
    int b = n ~/ 3;
    if (a != 0) {
      return b + 1;
    }
    return b;
  }

  Future<Null> _pullToRefresh() async {
    curPage = 1;
    getTweetsList(false, false);
    return null;
  }

  Widget getHotListView() {
    if (hotTweetsList == null) {
      getTweetsList(false, true);
      return Center(
        child: CircularProgressIndicator(),
      );
    } else {
      // ??????????????????
      return ListView.builder(
        itemCount: hotTweetsList.length * 2 - 1,
        itemBuilder: (context, i) => renderHotRow(i),
      );
    }
  }

  Widget getNormalListView() {
    if (normalTweetsList == null) {
      getTweetsList(false, false);
      return Center(
        child: CircularProgressIndicator(),
      );
    } else {
      // ??????????????????
      return RefreshIndicator(
        child: ListView.builder(
          itemCount: normalTweetsList.length * 2 - 1,
          itemBuilder: (context, i) => renderNormalRow(i),
          physics: const AlwaysScrollableScrollPhysics(),
          controller: _controller,
        ),
        onRefresh: _pullToRefresh);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isUserLogin) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(10.0),
              child: Center(
                child: Column(
                  children: <Widget>[
                    Text("??????OSC???Open API??????"),
                    Text("???????????????????????????????????????")
                  ],
                ),
              )
            ),
            InkWell(
              child: Container(
                padding: const EdgeInsets.fromLTRB(15.0, 8.0, 15.0, 8.0),
                child: Text("?????????"),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black),
                  borderRadius: BorderRadius.all(Radius.circular(5.0))
                ),
              ),
              onTap: () async {
                final result = await Navigator.of(context).push(MaterialPageRoute(builder: (BuildContext context) {
                  return NewLoginPage();
                }));
                if (result != null && result == "refresh") {
                  // ????????????????????????
                  Config.eventBus.fire(LoginEvent());
                }
              },
            ),
          ],
        ),
      );
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: TabBar(
          labelColor: Colors.black,
          tabs: <Widget>[
            Tab(text: "????????????"),
            Tab(text: "????????????")
          ],
        ),
        body: TabBarView(
          children: <Widget>[getNormalListView(), getHotListView()],
        )),
    );
  }
}