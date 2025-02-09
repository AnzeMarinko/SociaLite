import SwiftUI
import WebKit

struct ContentView: View {
    @State private var showSettings = false
    @State private var apiKey: String = UserDefaults.standard.string(forKey: "apiKey") ?? ""
    @State private var inputAPIKey: String = ""  // Lokalna spremenljivka za vnos
    @State private var channelId: String = ""
    @State private var channelName: String = ""
    @State private var channels: [String: String] = UserDefaults.standard.dictionary(forKey: "channels") as? [String: String] ?? [:]
    @State private var hiddenChannels: [String] = UserDefaults.standard.stringArray(forKey: "hiddenChannels") ?? []
    @State private var videos: [Video] = []
    
    var body: some View {
        ZStack {
            NavigationView {
                VStack {
                    // Gumb za nastavitve
                    Button("⚙️ Nastavitve") {
                        showSettings.toggle()
                    }
                    .padding()
                    
                    // Seznam videov
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))]) {
                            ForEach(videos.filter { !hiddenChannels.contains($0.channelId) }, id: \.id) { video in
                                VideoView(video: video)
                            }
                        }
                    }
                    .navigationTitle("SociaLite")
                    .preferredColorScheme(.dark)  // Aktiviraj temni način
                    
                    // Gumb za osvežitev videov
                    Button("🔄 Osveži videe") {
                        fetchVideos()
                    }
                    .padding()
                    .foregroundColor(.blue)
                }
            }
            
            if showSettings {
                VStack {
                    
                    
                    Form {
                        HStack {
                            Button("❌ Zapri nastavitve") {
                                showSettings.toggle()
                            }
                            .padding()
                            Spacer()
                        }
                    
                        Section(header: Text("📌 Seznam kanalov")) {
                            ForEach(channels.keys.sorted(), id: \.self) { channelId in
                                HStack {
                                    Text(channels[channelId] ?? "Neznan kanal")
                                    Spacer()
                                    
                                    // Gumb za skritje ali prikaz kanala
                                    if hiddenChannels.contains(channelId) {
                                        Button("👁 Prikaži") {
                                            hiddenChannels.removeAll { $0 == channelId }
                                            UserDefaults.standard.setValue(hiddenChannels, forKey: "hiddenChannels")
                                        }
                                    } else {
                                        Button("🙈 Skrij") {
                                            hiddenChannels.append(channelId)
                                            UserDefaults.standard.setValue(hiddenChannels, forKey: "hiddenChannels")
                                        }
                                    }

                                    Button("🗑 Odstrani") {
                                        channels.removeValue(forKey: channelId)
                                        UserDefaults.standard.setValue(channels, forKey: "channels")
                                        // Skrbno odstrani tudi skrite kanale
                                        hiddenChannels.removeAll { $0 == channelId }
                                        UserDefaults.standard.setValue(hiddenChannels, forKey: "hiddenChannels")
                                    }
                                    .foregroundColor(.red)
                                }
                            }
                        }
                        
                        Section(header: Text("🔑 API ključ")) {
                            if (apiKey.isEmpty) {
                                TextField("Vnesi API ključ", text: $inputAPIKey)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .disableAutocorrection(true)
                                    .autocapitalization(.none)
                                
                                Button("Shrani API ključ") {
                                    apiKey = inputAPIKey
                                    UserDefaults.standard.setValue(apiKey, forKey: "apiKey")
                                }
                            } else {
                                Text("API ključ je shranjen")
                                    .foregroundColor(.green)
                            }
                            
                            Button("❌ Odstrani API ključ") {
                                apiKey = ""
                                UserDefaults.standard.removeObject(forKey: "apiKey")
                            }
                            .foregroundColor(.red)
                            Text("API ključ je potreben za pridobivanje videov. Pridobite ga v Google Cloud Console, kjer morate omogočiti tudi YouTube Data API v3. API ključ je shranjen samo lokalno v aplikaciji.")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Section(header: Text("📺 Dodaj YouTube kanal")) {
                            TextField("Vnesi ID kanala", text: $channelId)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onChange(of: channelId) { newId in
                                    if !newId.isEmpty {
                                        fetchChannelName(from: newId)
                                    }
                                }
                            
                            if !channelName.isEmpty {
                                Text("Ime kanala: \(channelName)")
                                    .foregroundColor(.green)
                            }
                            
                            Button("➕ Dodaj kanal") {
                                if !channelId.isEmpty && !channelName.isEmpty {
                                    channels[channelId] = channelName
                                    UserDefaults.standard.setValue(channels, forKey: "channels")
                                    channelId = ""
                                    channelName = ""
                                    fetchVideos()  // Po dodajanju kanala osveži videe
                                }
                            }
                        }

                        Section(header: Text("🔍 Iskalnik ID-jev")) {
                            Link("Poišči ID kanala", destination: URL(string: "https://www.tunepocket.com/youtube-channel-id-finder/#channle-id-finder-form")!)
                                .foregroundColor(.blue)
                            Text("Poiščite ID kanala, ki ga želite spremljati. V aplikaciji boste videli zadnje 3 objave vsakega izbranega kanala. Priporočamo, da sledite malemu številu kanalov.")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Section {
                            Link("Anže Marinko (anzemarinko.github.io)", destination: URL(string: "https://anzemarinko.github.io")!)
                                .foregroundColor(.blue)
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(10)
                    .padding()
                }
                .background(Color.black.opacity(0.6))
                .edgesIgnoringSafeArea(.all)
            }
        }
    }
    
    func fetchChannelName(from channelId: String) {
        guard !apiKey.isEmpty else { return }
        
        let url = "https://www.googleapis.com/youtube/v3/channels?key=\(apiKey)&id=\(channelId)&part=snippet"
        
        guard let requestUrl = URL(string: url) else { return }
        
        URLSession.shared.dataTask(with: requestUrl) { data, _, error in
            if let data = data, let response = try? JSONDecoder().decode(YouTubeChannelResponse.self, from: data) {
                DispatchQueue.main.async {
                    if let name = response.items.first?.snippet.title {
                        self.channelName = name
                    }
                }
            }
        }.resume()
    }
    
    func fetchVideos() {
        guard !apiKey.isEmpty else { return }
        
        var fetchedVideos: [Video] = []
        
        for channelId in channels.keys {
            let url = "https://www.googleapis.com/youtube/v3/videos?key=\(apiKey)&channelId=\(channelId)&part=snippet,contentDetails&maxResults=3"
            
            guard let requestUrl = URL(string: url) else { continue }
            
            URLSession.shared.dataTask(with: requestUrl) { data, _, error in
                if let data = data, let response = try? JSONDecoder().decode(YouTubeResponse.self, from: data) {
                    DispatchQueue.main.async {
                        fetchedVideos.append(contentsOf: response.items.map { Video(id: $0.id, title: $0.snippet.title, channelId: channelId, duration: $0.contentDetails.duration) })
                        videos = fetchedVideos.sorted { $0.id > $1.id }
                    }
                }
            }.resume()
        }
    }
}

// Modeli za dekodiranje JSON odgovora
struct YouTubeResponse: Codable {
    let items: [YouTubeVideo]
}

struct YouTubeVideo: Codable {
    let id: String
    let snippet: Snippet
    let contentDetails: ContentDetails
}

struct Snippet: Codable {
    let title: String
}

struct ContentDetails: Codable {
    let duration: String
}

struct YouTubeChannelResponse: Codable {
    let items: [YouTubeChannel]
}

struct YouTubeChannel: Codable {
    let snippet: ChannelSnippet
}

struct ChannelSnippet: Codable {
    let title: String
}

// Model videa
struct Video: Identifiable {
    let id: String
    let title: String
    let channelId: String
    let duration: String
}

// Pogled za prikaz videov
struct VideoView: View {
    var video: Video

    var body: some View {
        VStack {
            WebView(url: URL(string: "https://www.youtube-nocookie.com/embed/\(video.id)?rel=0&modestbranding=1&controls=1")!)
                .frame(height: 200)
            
            Text(video.title)
                .font(.caption)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
            
            // Prikaz dolžine videa
            Text(formatDuration(video.duration))
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
        .padding()
    }
    
    // Funkcija za formatiranje trajanja videa v format "mm:ss"
    func formatDuration(_ duration: String) -> String {
        // Format dolžine videa je npr. "PT1M30S"
        let regex = try? NSRegularExpression(pattern: "(\\d+)M(\\d+)S", options: [])
        if let match = regex?.firstMatch(in: duration, options: [], range: NSRange(duration.startIndex..., in: duration)) {
            let minutes = (duration as NSString).substring(with: match.range(at: 1))
            let seconds = (duration as NSString).substring(with: match.range(at: 2))
            return "\(minutes) min \(seconds) sek"
        }
        return "Neznana dolžina"
    }
}

// WebView za prikaz YouTube videov
struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        return WKWebView()
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.load(URLRequest(url: url))
    }
}
