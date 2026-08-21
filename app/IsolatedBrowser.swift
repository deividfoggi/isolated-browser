import Cocoa
import WebKit

// Isolated Browser — app nativo (ADR-0003 + ADR-0005).
// Sobe o container Neko efêmero, carrega o cliente WebRTC num WKWebView privado
// (janela maximizada, sem fullscreen do macOS) e, ao fechar a janela, encerra o app
// e mata o container (--rm remove tudo) — efemeridade autêntica (RF-005 / INV-002).

let kContainerBin = "/usr/local/bin/container"
let kImage = "ghcr.io/m1k1o/neko/chromium:3.1.5"
let kName = "isolated-browser"
let kPort = 8080
let kEPR = "52000-52100"

@discardableResult
func runContainer(_ args: [String], wait: Bool = true) -> String {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: kContainerBin)
    p.arguments = args
    let pipe = Pipe()
    p.standardOutput = pipe
    p.standardError = pipe
    do { try p.run() } catch { return "" }
    guard wait else { return "" }
    p.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8) ?? ""
}

func stopContainer() {
    runContainer(["stop", kName])
    runContainer(["rm", kName])
}

func startContainer() {
    stopContainer()
    runContainer([
        "run", "--rm", "-d", "--name", kName,
        "--env", "NEKO_SERVER_BIND=0.0.0.0:\(kPort)",
        "--env", "NEKO_EPR=\(kEPR)",
        "--env", "NEKO_SESSION_COOKIE_SECURE=false",
        "--env", "NEKO_SESSION_IMPLICIT_HOSTING=true",
        "--env", "NEKO_MEMBER_MULTIUSER_USER_PROFILE={\"is_admin\":true}",
        kImage,
    ])
}

func resolveIP() -> String? {
    for _ in 0..<40 {
        let out = runContainer(["ls"])
        for line in out.split(separator: "\n") where line.contains(kName) {
            if let m = line.range(of: #"(\d{1,3}\.){3}\d{1,3}"#, options: .regularExpression) {
                return String(line[m])
            }
        }
        Thread.sleep(forTimeInterval: 0.5)
    }
    return nil
}

func waitHTTP(_ ip: String) -> Bool {
    guard let url = URL(string: "http://\(ip):\(kPort)/") else { return false }
    for _ in 0..<60 {
        let sem = DispatchSemaphore(value: 0)
        var ok = false
        var req = URLRequest(url: url)
        req.timeoutInterval = 1.5
        let task = URLSession.shared.dataTask(with: req) { _, resp, _ in
            if resp != nil { ok = true }
            sem.signal()
        }
        task.resume()
        _ = sem.wait(timeout: .now() + 2.0)
        if ok { return true }
        Thread.sleep(forTimeInterval: 0.5)
    }
    return false
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var web: WKWebView!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .nonPersistent()            // privado: nada persiste no host
        cfg.mediaTypesRequiringUserActionForPlayback = []   // autoplay de áudio liberado
        cfg.allowsAirPlayForMediaPlayback = false

        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        web = WKWebView(frame: screen, configuration: cfg)

        // Janela normal MAXIMIZADA (sem fullscreen do macOS / sem Space separado).
        window = NSWindow(contentRect: screen,
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = "Isolated Browser"
        window.contentView = web
        window.setFrame(screen, display: true)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        showLoading("Iniciando browser isolado…")

        // Sobe o container e carrega o cliente fora da main thread.
        DispatchQueue.global(qos: .userInitiated).async {
            startContainer()
            guard let ip = resolveIP(), waitHTTP(ip) else {
                DispatchQueue.main.async { self.showLoading("Falha ao iniciar o container.") }
                return
            }
            let url = URL(string: "http://\(ip):\(kPort)/?usr=neko&pwd=neko&embed=1")!
            DispatchQueue.main.async { self.web.load(URLRequest(url: url)) }
        }
    }

    func showLoading(_ msg: String) {
        let html = """
        <html><body style="margin:0;background:#111;color:#eee;font-family:-apple-system,Helvetica,Arial;
        display:flex;align-items:center;justify-content:center;height:100vh">
        <div style="text-align:center"><div style="font-size:20px">\(msg)</div></div></body></html>
        """
        web.loadHTMLString(html, baseURL: nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true   // fechar a janela encerra o app
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopContainer()   // mata o container ao sair (efemeridade)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
