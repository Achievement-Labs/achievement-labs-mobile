import SwiftUI
import WebKit
import UniformTypeIdentifiers
import CryptoKit
import LabsMobileCore

struct Xbox360View: View {
    @EnvironmentObject var model: MobileModel
    @EnvironmentObject var appearance: MobileAppearance
    var body: some View { NavigationStack { Xbox360WebView(model:model,appearance:appearance).labsPage().navigationTitle("Xbox 360").navigationBarTitleDisplayMode(.inline) } }
}

private struct Xbox360WebView: UIViewRepresentable {
    let model: MobileModel
    let appearance:MobileAppearance
    func makeCoordinator() -> Coordinator { Coordinator(model:model) }
    func makeUIView(context:Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.userContentController.add(context.coordinator,name:"labs360")
        let web = WKWebView(frame:.zero,configuration:config)
        web.isOpaque = false; web.backgroundColor = .black
        web.navigationDelegate = context.coordinator; context.coordinator.web = web
        if let folder = Bundle.main.resourceURL?.appendingPathComponent("Shared360",isDirectory:true) {
            context.coordinator.folder = folder
            web.loadFileURL(folder.appendingPathComponent("index.html"),allowingReadAccessTo:folder)
        }
        return web
    }
    func updateUIView(_ uiView:WKWebView,context:Context) { if context.coordinator.appearanceReady { context.coordinator.applyAppearance(uiView) } }
    static func dismantleUIView(_ uiView:WKWebView,coordinator:Coordinator) { uiView.configuration.userContentController.removeScriptMessageHandler(forName:"labs360"); uiView.navigationDelegate = nil }

    @MainActor final class Coordinator: NSObject,WKScriptMessageHandler,WKNavigationDelegate,UIDocumentPickerDelegate {
        weak var web: WKWebView?
        let model: MobileModel
        var folder: URL?
        var original = Data(), working = Data(), pending: Data?
        var expected = 0, digest = "", directory: URL?
        var pickerID: String?, pickerAction = ""
        var appearanceReady=false, lastAppearance=""
        // Public, download-only GPD catalog; every file must match the index size and SHA-256.
        static let catalogBase = "https://raw.githubusercontent.com/Achievement-Labs/achievement-labs/gpd-catalog/"
        static let issueURL = "https://github.com/Achievement-Labs/achievement-labs/issues/new?template=gpd-contribution.yml&title="
        var catalog:[String:[String:Any]]?, gpd = Data(), contribution:Data?, contributionTitle = "", contributionLength = 0, contributionHash = ""
        func sha256(_ data:Data) -> String { SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined() }
        func validTitle(_ id:String) -> Bool { id.range(of:"^[0-9A-F]{8}$",options:.regularExpression) != nil && id != "FFFE07D1" }
        func download(_ path:String,limit:Int) async throws -> Data {
            var request = URLRequest(url:URL(string:Self.catalogBase+path)!); request.timeoutInterval = 60; request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("AchievementLabs-Mobile/0.3",forHTTPHeaderField:"User-Agent")
            let (data,response) = try await URLSession.shared.data(for:request)
            guard let http = response as? HTTPURLResponse,(200...299).contains(http.statusCode),data.count <= limit else { throw fail("The GPD catalog is unavailable (HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)).") }
            return data
        }
        func parseCatalog(_ data:Data) throws -> [String:[String:Any]] {
            guard let root = try JSONSerialization.jsonObject(with:data) as? [String:Any],root["version"] as? Int == 1,let titles = root["titles"] as? [String:[String:Any]] else { throw fail("Unsupported GPD catalog.") }
            var clean:[String:[String:Any]] = [:]
            for (id,t) in titles {
                guard validTitle(id),let size = t["bytes"] as? Int,size > 0,size <= 8*1024*1024,let hash = t["sha256"] as? String,hash.range(of:"^[0-9a-f]{64}$",options:.regularExpression) != nil else { throw fail("Invalid GPD catalog entry \(id).") }
                clean[id] = ["name":t["name"] as? String ?? "","achievements":t["achievements"] as? Int ?? 0,"gamerscore":t["gamerscore"] as? Int ?? 0,"bytes":size,"sha256":hash]
            }
            return clean
        }
        var catalogCache:URL { FileManager.default.urls(for:.cachesDirectory,in:.userDomainMask)[0].appendingPathComponent("xbox360-gpd-index.json") }
        init(model:MobileModel) { self.model = model }
        func hash(_ data:Data) -> String { Insecure.SHA1.hash(data:data).map { String(format:"%02x",$0) }.joined() }
        func reply(_ id:String,_ result:Any = [:],error:String? = nil) {
            guard let web else { return }
            let envelope:[Any] = [id,result,error as Any? ?? NSNull()]
            guard let data = try? JSONSerialization.data(withJSONObject:envelope),let json = String(data:data,encoding:.utf8) else { return }
            web.evaluateJavaScript("window.native360Result(...\(json))",completionHandler:nil)
        }
        func userContentController(_ userContentController:WKUserContentController,didReceive message:WKScriptMessage) {
            guard message.frameInfo.isMainFrame, message.frameInfo.request.url?.isFileURL == true,
                  let path = message.frameInfo.request.url?.standardizedFileURL.path, let folder,
                  path == folder.appendingPathComponent("index.html").standardizedFileURL.path,
                  let body = message.body as? [String:Any],let id = body["id"] as? String,id.count <= 32,
                  let action = body["action"] as? String,let p = body["data"] as? [String:Any] else { return }
            Task { do { if let result = try await handle(action,p,id:id) { reply(id,result) } } catch { reply(id,error:error.localizedDescription) } }
        }
        func webView(_ webView:WKWebView,decidePolicyFor navigationAction:WKNavigationAction,decisionHandler:@escaping (WKNavigationActionPolicy)->Void) {
            let allowed = navigationAction.request.url?.standardizedFileURL == folder?.appendingPathComponent("index.html").standardizedFileURL
            decisionHandler(allowed ? .allow : .cancel)
        }
        func webView(_ webView:WKWebView,didFinish navigation:WKNavigation!) {
            appearanceReady=true;applyAppearance(webView)
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--ui-preview=xbox360") { webView.evaluateJavaScript("window.mobile360SelfTest()",completionHandler:nil) }
            #endif
        }
        func applyAppearance(_ webView:WKWebView) {
            let appearance=MobileAppearance()
            var config:[String:Any] = ["glassEnabled":appearance.glass,"oledMode":appearance.oled,"glassTint":"#"+appearance.tint,"accentColour":"#"+appearance.accent,"glassTransparency":appearance.transparency*100,"glassBlur":appearance.blur*40,"backgroundSource":appearance.background,"persistentGameArt":appearance.persistent,"artworkFit":appearance.fit ? "contain" : "cover","backgroundDim":appearance.dim*100,"backgroundBlur":appearance.artBlur]
            config["backgroundURL"]=model.gameForTitle(appearance.title)?.image ?? ""
            if appearance.background == "custom", let data=try? Data(contentsOf:MobileAppearance.customURL) { config["customImage"]="data:image/jpeg;base64,"+data.base64EncodedString() }
            if let data=try? JSONSerialization.data(withJSONObject:config),let json=String(data:data,encoding:.utf8) { if json != lastAppearance { lastAppearance=json;webView.evaluateJavaScript("window.setLabsAppearance(\(json))",completionHandler:nil) } }
        }
        func fail(_ text:String) -> LabsError { .message(text) }
        func privateWrite(_ data:Data,to url:URL) throws {
            try data.write(to:url,options:[.atomic,.completeFileProtectionUntilFirstUserAuthentication])
            guard try Data(contentsOf:url) == data else { throw fail("Private profile readback failed.") }
        }
        func verifiedExport(_ backup:Bool) throws -> URL {
            guard let directory, pending == nil,!working.isEmpty else { throw fail("No completed profile is available.") }
            let file = directory.appendingPathComponent(backup ? "original.con" : "working.con")
            guard try Data(contentsOf:file) == (backup ? original : working) else { throw fail("Private profile changed. Reload before export.") }
            let bytes = backup ? original : working
            guard bytes.count >= 0x379 else { throw fail("Profile header is missing.") }
            let name = bytes[0x371..<0x379].map { String(format:"%02X",$0) }.joined() + (backup ? ".original.bak" : "")
            let output = directory.appendingPathComponent(name)
            try privateWrite(bytes,to:output)
            return output
        }
        func handle(_ action:String,_ p:[String:Any],id:String) async throws -> Any? {
            switch action {
            #if DEBUG
            case "testProfile":
                guard ProcessInfo.processInfo.arguments.contains("--ui-preview=xbox360"),let folder else { throw fail("Test mode is unavailable.") }
                let bytes = try Data(contentsOf:folder.appendingPathComponent("synthetic.dat"))
                let next = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
                try FileManager.default.createDirectory(at:next,withIntermediateDirectories:true)
                try privateWrite(bytes,to:next.appendingPathComponent("original.con")); try privateWrite(bytes,to:next.appendingPathComponent("working.con"))
                original = bytes; working = bytes; directory = next; return ["length":bytes.count]
            case "testDone":
                guard ProcessInfo.processInfo.arguments.contains("--ui-preview=xbox360") else { throw fail("Test mode is unavailable.") }
                if p["passed"] as? Bool == true {
                    guard try Data(contentsOf:verifiedExport(true)) != Data(contentsOf:verifiedExport(false)) else { throw fail("Test output unchanged.") }
                }
                let file = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("Xbox360-self-test.json")
                try JSONSerialization.data(withJSONObject:p).write(to:file,options:.atomic); return [:]
            #endif
            case "pickProfile","pickReference","export":
                guard pickerID == nil,let web,let controller = web.window?.rootViewController else { throw fail("A document picker is already open or unavailable.") }
                let picker:UIDocumentPickerViewController
                if action == "export" { picker = UIDocumentPickerViewController(forExporting:[try verifiedExport(p["original"] as? Bool ?? false)],asCopy:true) }
                else { picker = UIDocumentPickerViewController(forOpeningContentTypes:[.data,.item],asCopy:true) }
                pickerID = id; pickerAction = action; picker.delegate = self
                var presenter = controller; while let next = presenter.presentedViewController { presenter = next }
                presenter.present(picker,animated:true); return nil
            case "identity":
                guard let folder else { throw fail("Signing assets are missing.") }
                let bytes = try Data(contentsOf:folder.appendingPathComponent("signing.dat"))
                guard bytes.count == 556 else { throw fail("Signing assets are invalid.") }
                return ["base64":bytes.base64EncodedString()]
            case "readChunk":
                guard let offset = p["offset"] as? Int,offset >= 0,offset < working.count else { throw fail("Invalid profile chunk.") }
                return ["base64":working.subdata(in:offset..<min(offset+32768,working.count)).base64EncodedString()]
            case "beginSave":
                guard let directory,pending == nil, let count = p["length"] as? Int,count == working.count,count <= 32*1024*1024,
                      let digest = p["sha1"] as? String,digest.range(of:"^[0-9a-f]{40}$",options:.regularExpression) != nil,
                      p["before"] as? String == hash(working),try Data(contentsOf:directory.appendingPathComponent("working.con")) == working else { throw fail("Working profile changed or save is invalid. Reload before editing.") }
                expected = count; self.digest = digest; pending = Data(); return [:]
            case "saveChunk":
                guard let offset = p["offset"] as? Int,let encoded = p["base64"] as? String,encoded.count <= 44000,let chunk = Data(base64Encoded:encoded),!chunk.isEmpty,chunk.count <= 32768,let current = pending,offset == current.count,offset+chunk.count <= expected else { throw fail("Invalid or out-of-order save chunk.") }
                pending!.append(chunk); return [:]
            case "commitSave":
                guard let directory,let next = pending,next.count == expected,hash(next) == digest else { throw fail("Signed profile transfer failed verification.") }
                try privateWrite(working,to:directory.appendingPathComponent("before-save-\(UUID().uuidString).con"))
                try privateWrite(next,to:directory.appendingPathComponent("working.con")); working = next; pending = nil; return [:]
            case "abortSave": pending = nil; return [:]
            case "art":
                let title = p["titleId"] as? String ?? ""
                let game = model.games.first { $0.id == title } ?? model.titleDetails[title]
                var result:[String:Any] = ["url":game?.image ?? ""]
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--ui-preview=xbox360") { return result }
                #endif
                if let images=try? await StoreArtwork.lookup(title) { result["images"]=images.map { ["url":$0.url.absoluteString,"width":$0.width,"height":$0.height,"purpose":$0.purpose] as [String:Any] } }
                return result
            case "reference":
                guard let account = model.account else { throw fail("Connect an Xbox account in Settings first.") }
                return ["rows":try await model.api.reference360(p["titleId"] as? String ?? "",gamertag:p["gamertag"] as? String ?? "",account:account)]
            case "gpdIndex":
                do { let data = try await download("index.json",limit:4*1024*1024); catalog = try parseCatalog(data); try? data.write(to:catalogCache,options:.atomic) }
                catch { guard let data = try? Data(contentsOf:catalogCache) else { throw error }; catalog = try parseCatalog(data) }
                return ["titles":catalog ?? [:],"contribute":model.gpdContribute]
            case "gpdFetch":
                guard let title = p["titleId"] as? String,validTitle(title),let entry = catalog?[title],let size = entry["bytes"] as? Int,let expected = entry["sha256"] as? String else { throw fail("That title is not in the GPD catalog.") }
                let data = try await download("gpd/\(title).gpd",limit:8*1024*1024)
                guard data.count == size,sha256(data) == expected else { throw fail("The downloaded GPD did not match the catalog checksum.") }
                gpd = data; return ["length":data.count]
            case "gpdChunk":
                guard let offset = p["offset"] as? Int,offset >= 0,offset < gpd.count else { throw fail("Invalid GPD chunk.") }
                return ["base64":gpd.subdata(in:offset..<min(offset+32768,gpd.count)).base64EncodedString()]
            case "contributeBegin":
                guard model.gpdContribute else { throw fail("Turn on GPD contributions in Settings first.") }
                guard let title = p["titleId"] as? String,validTitle(title),let length = p["length"] as? Int,length > 0,length <= 8*1024*1024,let digest = p["sha1"] as? String,digest.range(of:"^[0-9a-f]{40}$",options:.regularExpression) != nil else { throw fail("Invalid GPD contribution.") }
                contribution = Data(); contributionTitle = title; contributionLength = length; contributionHash = digest; return [:]
            case "contributeChunk":
                guard let offset = p["offset"] as? Int,let encoded = p["base64"] as? String,encoded.count <= 44000,let chunk = Data(base64Encoded:encoded),!chunk.isEmpty,let current = contribution,offset == current.count,offset+chunk.count <= contributionLength else { throw fail("Invalid or out-of-order GPD chunk.") }
                contribution!.append(chunk); return [:]
            case "contributeCommit":
                guard let bytes = contribution,bytes.count == contributionLength,hash(bytes) == contributionHash else { contribution = nil; throw fail("GPD contribution transfer failed verification.") }
                contribution = nil
                guard pickerID == nil,let web,let controller = web.window?.rootViewController else { throw fail("A document picker is already open or unavailable.") }
                let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
                try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
                let file = folder.appendingPathComponent(contributionTitle+".gpd"); try privateWrite(bytes,to:file)
                let picker = UIDocumentPickerViewController(forExporting:[file],asCopy:true)
                pickerID = id; pickerAction = action; picker.delegate = self
                var presenter = controller; while let next = presenter.presentedViewController { presenter = next }
                presenter.present(picker,animated:true); return nil
            default: throw fail("Unsupported Xbox 360 command.")
            }
        }
        func documentPickerWasCancelled(_ controller:UIDocumentPickerViewController) { if let id = pickerID { pickerID = nil; reply(id,["cancelled":true]) } }
        func documentPicker(_ controller:UIDocumentPickerViewController,didPickDocumentsAt urls:[URL]) {
            guard let id = pickerID else { return }; pickerID = nil
            do {
                guard let url = urls.first else { reply(id,["cancelled":true]); return }
                if pickerAction == "export" { reply(id); return }
                if pickerAction == "contributeCommit" {
                    let title = ("GPD contribution: "+contributionTitle).addingPercentEncoding(withAllowedCharacters:.urlQueryAllowed) ?? ""
                    if let issue = URL(string:Self.issueURL+title) { UIApplication.shared.open(issue) }
                    reply(id); return
                }
                let scoped = url.startAccessingSecurityScopedResource(); defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let max = pickerAction == "pickReference" ? 2*1024*1024 : 32*1024*1024
                let size = try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? Int.max
                guard size > 0,size <= max else { throw fail("Document exceeds the size limit.") }
                let bytes = try Data(contentsOf:url); guard bytes.count == size else { throw fail("Document changed while importing.") }
                if pickerAction == "pickReference" { guard let text = String(data:bytes,encoding:.utf8) else { throw fail("Reference file must use UTF-8.") };reply(id,["text":text]);return }
                guard pending == nil else { throw fail("Finish the current save first.") }
                var root = FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("Xbox360",isDirectory:true)
                try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
                var values = URLResourceValues(); values.isExcludedFromBackup = true; try root.setResourceValues(values)
                let next = root.appendingPathComponent(UUID().uuidString,isDirectory:true); try FileManager.default.createDirectory(at:next,withIntermediateDirectories:true)
                try privateWrite(bytes,to:next.appendingPathComponent("original.con"));try privateWrite(bytes,to:next.appendingPathComponent("working.con"))
                original = bytes; working = bytes; directory = next;reply(id,["length":bytes.count])
            } catch { reply(id,error:error.localizedDescription) }
        }
    }
}
