import UIKit

import Alamofire
import Nuke

struct Item {
    var itemid: Int?
    var itemname: String?
    var description: String?
    var price: Int?
    var pictureurl: String?
}

class ItemListVC: UITableViewController {
    
    //데이터를 저장하기 위한 배열
    var itemList = Array<Item>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "과일"
        //데이터를 저장할 sqlite 파일과
        //업데이트 한 시간을 저장할 텍스트 파일의 경로를 생성
        
        //파일 관리를 위한 객체 생성
        let fileMgr = FileManager.default
        //도큐먼트 디렉토리 경로 생성
        let docPath = fileMgr.urls(for: .documentDirectory, in: .userDomainMask).first!
        //데이터베이스 파일의 경로
        let dbPath = docPath.appendingPathComponent("item.sqlite").path
        //업데이트 정보를 저장할 파일의 경로
        let updatePath = docPath.appendingPathComponent("update.txt").path
        
        //데이터를 다운로드 받을 URL을 생성
        let url = "http://cyberadam.cafe24.com/item/list"
        
        //기존 데이터가 없을 때
        if fileMgr.fileExists(atPath: dbPath) == false {
            //대화상자 출력
            let alert = UIAlertController(title: "데이터 가져오기", message: "기존 데이터가 없어서 다운로드", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "확인", style: .default))
            self.present(alert, animated: true)
            
            //로컬 데이터 생성
            let itemDB = FMDatabase(path: dbPath)
            itemDB.open()
            
            //Alamofire를 이용해서 파라미터 없이 get 방식으로 데이터(json) 가져오기
            //웹 서버에게 요청: url, parameter, header
            //오픈 API에서 header는 보안을 위해서 설정
            //예전에는 키를 파라미터로 전송
            //키가 노출되는 경우가 많아서 최근에는
            //key를 header에 숨겨서 전송한다.
            let request = AF.request(url, method: .get, encoding: JSONEncoding.default, headers: [:])
            
            //비동기 - JSON 데이터를 다운로드 받은 경우
            request.responseJSON {
                response in
                //가져온 데이터는 response.value
                //전체 데이터를 딕셔너리로 변환
                if let jsonObject = response.value as? [String: Any] {
                    //list 라는 키의 데이터를 배열로 가져오기
                    let list = jsonObject["list"] as! NSArray
                    //sqlite 에 데이터를 저장할 테이블을 생성
                    let sql = "create table item(itemid INTEGER not null primary key, itemname TEXT, price INTEGER, description TEXT, pictureurl TEXT)"
                    itemDB.executeStatements(sql)
                    
                    //배열을 순회하면서 itemList 와
                    //item 테이블에 데이터를 추가
                    for idx in 0...list.count - 1 {
                        //데이터 1개 읽기
                        let itemDict = list[idx] as! NSDictionary
                        //itemList에 추가하기
                        var item = Item()
                        item.itemid = (itemDict["itemid"] as! NSNumber).intValue
                        item.itemname = itemDict["itemname"] as? String
                        item.description = itemDict["description"] as? String
                        item.price = (itemDict["price"] as! NSNumber).intValue
                        item.pictureurl = itemDict["pictureurl"] as? String
                        self.itemList.append(item)
                        
                        //테이블에 데이터를 삽입
                        let sql = "insert into item(itemid, itemname, price, description, pictureurl) values(:itemid, :itemname, :price, :description, :pictureurl)"
                        //sql 파라미터 만들기
                        var paramDict = [String: Any]()
                        paramDict["itemid"] = item.itemid
                        paramDict["itemname"] = item.itemname
                        paramDict["price"] = item.price
                        paramDict["description"] = item.description
                        paramDict["pictureurl"] = item.pictureurl
                        
                        //SQL 실행
                        itemDB.executeUpdate(sql, withParameterDictionary: paramDict)
                    }
                }
                //테이블 뷰 다시 출력
                self.tableView.reloadData()
                //데이터베이스 닫기
                itemDB.close()
                
                //업데이트 한 시간 다운로드 받아서 파일에 저장하기
                //url 생성
                let updateUrl = "http://cyberadam.cafe24.com/item/date"
                //요청 생성
                let updateRequest = AF.request(updateUrl, method: .get, encoding: JSONEncoding.default, headers: [:])
                updateRequest.responseJSON {
                    response in
                    if let jsonObject = response.value as? [String: Any] {
                        //result 키의 데이터 읽어오기
                        let result = jsonObject["result"] as? String
                        //문자열을 바이트 배열로 변환
                        let dataBuffer = result?.data(using: String.Encoding.utf8)
                        //파일에 저장
                        fileMgr.createFile(atPath: updatePath, contents: dataBuffer, attributes: nil)
                    }
                }
            }
        }
            //데이터가 존재하는 경우
        else {
            //파일에 저장된 업데이트 시간을 찾아온다.
            let dataBuffer = fileMgr.contents(atPath: updatePath)
            let updateTime = NSString(data: dataBuffer!, encoding: String.Encoding.utf8.rawValue) as String?
            
            //서버의 데이터 업데이트 시간을 찾아온다.
            let updateUrl = "http://cyberadam.cafe24.com/item/date"
            //데이터 요청
            let updateRequest = AF.request(updateUrl, method: .get, encoding: JSONEncoding.default, headers: [:])
            //JSON 형식으로 데이터가 도착하면 수행
            updateRequest.responseJSON {
                response in
                //전체 데이터를 딕셔너리로 변경
                if let jsonObject = response.value as? [String: Any] {
                    //서버의 업데이트 시간을 가져옴
                    let result = jsonObject["result"] as? String
                    
                    //서버의 업데이트 시간과 로컬 데이터의 업데이트 시간이 같은 경우
                    if updateTime == result {
                        NSLog("서버와 로컬의 업데이트 시간이 같음")
                        //이 경우에는 로컬에 있는 데이터를 가지고 출력
                        
                        //데이터베이스 연결
                        let itemDB = FMDatabase(path: dbPath)
                        itemDB.open()
                        //SQL 만들기
                        let sql = "select * from item"
                        //sql 실행
                        let rs = try! itemDB.executeQuery(sql, values: nil)
                        //기존 데이터 전부 제거
                        self.itemList.removeAll()
                        //읽어온 데이터를 순회하면서 itemList에 추가
                        while rs.next() {
                            var item = Item()
                            item.itemid = Int(rs.int(forColumn: "itemid"))
                            item.itemname = rs.string(forColumn: "itemname")
                            item.price = Int(rs.int(forColumn: "price"))
                            item.description = rs.string(forColumn: "description")
                            item.pictureurl = rs.string(forColumn: "pictureurl")
                            
                            self.itemList.append(item)
                        }
                        //데이터 재출력
                        self.tableView.reloadData()
                        itemDB.close()
                    }
                        //서버의 업데이트 시간과 로컬 데이터의 업데이트 시간이 다른 경우
                    else {
                        NSLog("서버와 로컬의 업데이트 시간이 다름")
                        //2개의 파일을 삭제
                        try! fileMgr.removeItem(atPath: dbPath)
                        try! fileMgr.removeItem(atPath: updatePath)
                        
                        //로컬의 데이터베이스 생성
                        let itemDB = FMDatabase(path: dbPath)
                        itemDB.open()
                        
                        //get 방식의 데이터 가져오기
                        let request = AF.request(url, method: .get, encoding: JSONEncoding.default, headers: [:])
                        //전송된 JSON 데이터 읽기
                        request.responseJSON {
                            response in
                            
                            //전송된 데이터를 읽어서 Dictionary로 변환
                            if let jsonObject = response.value as? [String: Any] {
                                //데이터 목록 찾아오기
                                let list = jsonObject["list"] as! NSArray
                                //저장할 테이블 생성
                                let sql = "create table item(itemid INTEGER not null primary key, itemname TEXT, price INTEGER, description TEXT, pictureurl TEXT)"
                                itemDB.executeStatements(sql)
                                
                                //배열 순회
                                for idx in 0...list.count - 1 {
                                    //데이터 1개 가져오기
                                    let itemDict = list[idx] as! NSDictionary
                                    //Dictionary의 데이터를 읽어서 Item 만들기
                                    var item = Item()
                                    item.itemid = (itemDict["itemid"] as! NSNumber).intValue
                                    item.itemname = itemDict["itemname"] as? String
                                    item.price = (itemDict["price"] as! NSNumber).intValue
                                    item.description = itemDict["description"] as? String
                                    item.pictureurl = itemDict["pictureurl"] as? String
                                    self.itemList.append(item)
                                    
                                    //데이터베이스 삽입
                                    
                                    //SQL 생성
                                    let sql = "insert into item(itemid, itemname, price, description, pictureurl) values(:itemid, :itemname, :price, :description, :pictureurl)"
                                    
                                    //파라미터 딕셔너리를 생성
                                    var paramDict = [String: Any]()
                                    paramDict["itemid"] = item.itemid
                                    paramDict["itemname"] = item.itemname
                                    paramDict["price"] = item.price
                                    paramDict["description"] = item.description
                                    paramDict["pictureurl"] = item.pictureurl
                                    
                                    //데이터 삽입
                                    itemDB.executeUpdate(sql, withParameterDictionary: paramDict)
                                }
                            }
                            self.tableView.reloadData()
                            itemDB.close()
                            
                            //업데이트 한 시간 저장하기
                            let updateUrl = "http://cyberadam.cafe24.com/item/date"
                            let updateRequest = AF.request(updateUrl, method: .get, encoding: JSONEncoding.default, headers: [:])
                            updateRequest.responseJSON {
                                response in
                                if let jsonObject = response.value as? [String: Any] {
                                    let result = jsonObject["result"] as? String
                                    //result를 파일에 기록
                                    let dataBuffer = result!.data(using: String.Encoding.utf8)
                                    fileMgr.createFile(atPath: updatePath, contents: dataBuffer!, attributes: nil)
                                }
                            }
                        }
                    }
                }
            }
        }
        //편집 버튼을 네비게이션 바의 왼쪽에 배치
        self.navigationItem.leftBarButtonItem = self.editButtonItem
    }
    
    // MARK: - Table view data source
    //편집 버튼을 눌렀을 때 보여질 아이콘 모양을 설정하는 메소드
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    
    //삭제 버튼을 눌렀을 때 동작할 메소드
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        
        //1. 데이터를 찾아오기
        let itemid = itemList[indexPath.row].itemid
        
        //2. POST 방식의 파라미터 만들기 - [String: String]
        let parameters = ["itemid": "\(itemid!)"]
        
        //3. POST 방식 요청
        let request = AF.request("http://cyberadam.cafe24.com/item/delete", method: .post, parameters: parameters, encoding: URLEncoding.httpBody, headers: [:])
        
        //4. 응답이오면 수행
        request.responseJSON {
            response in
            if let jsonObject = response.value as? [String: Any] {
                //json 형식의 데이터가 iOS에게 전달될 때
                //true 와 false 만 있는 경우에는 1 과 0으로 리턴
                NSLog(jsonObject.description)
                
                //결과 가져오기
                let result = jsonObject["result"] as! Int32
                
                //메시지 만들기
                var msg: String!
                if result == 1 {
                    msg = "삭제 성공"
                } else {
                    msg = "삭제 실패"
                }
                
                let alert = UIAlertController(title: "데이터 삭제", message: msg, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "확인", style: .default))
                
                self.present(alert, animated: true)
                
                //서버의 데이터 갱신 작업 후 재출력
                //서버에 데이터 갱신 작업을 수행하고 데이터를 다시 가져와서 출력
                //테이블의 데이터를 혼자서만 사용하는 경우 자원의 낭비
                //대표적인 예가 EMAIL 이나 ToDo 앱
                //서버에게 데이터 갱신을 요청하고
                //자신의 데이터를 삭제하고 재출력 - 비연결형 DB 라고도 함
                self.itemList.remove(at: indexPath.row)
                //iOS에서는 테이블 뷰를 재출력하는 방법이 2가지
                //하나는 reloadData() 호출
                //insertRows 나 deleteRows를 이용해서
                //애니메이션을 추가
                
                //self.tableView.reloadData()
                
                self.tableView.deleteRows(at: [indexPath], with: .left)
            }
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return itemList.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        //출력할 데이터 찾기
        let item = itemList[indexPath.row]
        
        var cell = tableView.dequeueReusableCell(withIdentifier: "cell")
        if cell == nil {
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        }
        
        cell!.textLabel!.text = item.itemname
        cell!.detailTextLabel!.text = item.description
        
        //이미지 출력
        //GUI 프로그램에서는 main 스레드가 아닌 스레드에서
        //UI 갱신이 안된다.
        //UI를 갱신하고자 할 때는 main 스레드에 코드를 작성해야 한다.
        DispatchQueue.main.async(execute: {
            //이미지를 다운로드 받을 URL
            let url: URL! = URL(string: "http://cyberadam.cafe24.com/img/\(item.pictureurl!)")
            //Nuke 라이브러리를 이용해서 비동기적으로 다운로드 받아서 출력
            let options = ImageLoadingOptions(
                placeholder: UIImage(named: "placeholder"), transition: .fadeIn(duration: 2)
            )
            Nuke.loadImage(with: url!, options: options, into: cell!.imageView!)
        })
        
        return cell!
    }
    
    
    /*
     // Override to support conditional editing of the table view.
     override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
     // Return false if you do not want the specified item to be editable.
     return true
     }
     */
    
    /*
     // Override to support editing the table view.
     override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
     if editingStyle == .delete {
     // Delete the row from the data source
     tableView.deleteRows(at: [indexPath], with: .fade)
     } else if editingStyle == .insert {
     // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
     }
     }
     */
    
    /*
     // Override to support rearranging the table view.
     override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {
     
     }
     */
    
    /*
     // Override to support conditional rearranging of the table view.
     override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
     // Return false if you do not want the item to be re-orderable.
     return true
     }
     */
    
    /*
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destination.
     // Pass the selected object to the new view controller.
     }
     */
    
}
