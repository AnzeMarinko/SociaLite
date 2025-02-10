import SwiftUI
import WebKit

struct ContentView: View {
    @State private var showSettings = false
    @State private var apiKey: String = UserDefaults.standard.string(forKey: "apiKey") ?? ""
    @State private var inputAPIKey: String = ""  // Lokalna spremenljivka za vnos
    @State private var channelId: String = ""
    @State private var inputChannelId: String = ""
    @State private var channelName: String = ""
    @State private var channels: [String: String] = UserDefaults.standard.dictionary(forKey: "channels") as? [String: String] ?? [:]
    @State private var videos: [Video] = []
    
    var body: some View {
        ZStack {
            NavigationView {
                VStack {
                    HStack {
                        // Gumb za nastavitve
                        Button("⚙️ Nastavitve") {
                            showSettings.toggle()
                        }
                        .foregroundColor(.orange)
                        Spacer()
                        
                        // Gumb za osvežitev videov
                        Button("🔄 Osveži videe") {
                            fetchVideos()
                        }
                        .foregroundColor(.orange)
                    }
                    
                    // Seznam videov
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 250))]) {
                            ForEach(videos, id: \.id) { video in
                                VideoView(video: video)
                            }
                        }
                    }
                    .navigationTitle("SociaLite").foregroundColor(.orange)
                    .preferredColorScheme(.dark)  // Aktiviraj temni način
                }
            }
            
            if showSettings {
                VStack {
                    
                    
                    Form {
                        HStack {
                            Button("❌ Zapri nastavitve") {
                                showSettings.toggle()
                            }
                            Spacer()
                        }
                    
                        Section(header: Text("📌 Seznam kanalov")) {
                            ForEach(channels.keys.sorted(), id: \.self) { channelId in
                                HStack {
                                    Text(channels[channelId] ?? "Neznan kanal")
                                    Spacer()

                                    Button("🗑 Odstrani") {
                                        channels.removeValue(forKey: channelId)
                                        UserDefaults.standard.setValue(channels, forKey: "channels")
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
                            TextField("Vnesi ID kanala", text: $inputChannelId)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Button("➕ Dodaj kanal") {
                                fetchChannelName(from: inputChannelId)
                                print("channelName: \(channelName)")
                                if !inputChannelId.isEmpty && !channelName.isEmpty {
                                    channels[inputChannelId] = channelName
                                    UserDefaults.standard.setValue(channels, forKey: "channels")
                                    inputChannelId = ""
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
    
    func fetchChannelName(from inputChannelId: String) {
        guard !apiKey.isEmpty else { return }
        
        let url = "https://www.googleapis.com/youtube/v3/channels?key=\(apiKey)&id=\(inputChannelId)&part=snippet"
        guard let requestUrl = URL(string: url) else { return }
        
        URLSession.shared.dataTask(with: requestUrl) { data, _, error in
            if let error = error {
                print("Napaka pri nalaganju podatkov: \(error.localizedDescription)")
                return
            }
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
        var videoIds: [String] = []

        let group = DispatchGroup() // Za sinhronizacijo klicev

        for channelId in channels.keys {
            let url = "https://www.googleapis.com/youtube/v3/search?key=\(apiKey)&channelId=\(channelId)&part=snippet,id&order=date&maxResults=3"
            
            guard let requestUrl = URL(string: url) else { continue }

            group.enter()
            URLSession.shared.dataTask(with: requestUrl) { data, _, error in
                defer { group.leave() }
                if let data = data, let response = try? JSONDecoder().decode(YouTubeResponse.self, from: data) {
                    DispatchQueue.main.async {
                        let newVideos = response.items.compactMap { item -> Video? in
                            guard let videoId = item.id.videoId else { return nil }
                            videoIds.append(videoId)
                            return Video(id: videoId, title: item.snippet.title, channelName: item.snippet.channelTitle, duration: "", publishedAt: item.snippet.publishedAt, description: item.snippet.description)
                        }
                        fetchedVideos.append(contentsOf: newVideos)
                    }
                }
            }.resume()
        }

        group.notify(queue: .main) {
            fetchVideoDurations(for: videoIds) { durations in
                for i in fetchedVideos.indices {
                    if let duration = durations[fetchedVideos[i].id] {
                        fetchedVideos[i].duration = duration
                    }
                }
                videos = fetchedVideos.sorted { $0.publishedAt > $1.publishedAt }
            }
        }
    }

    func fetchVideoDurations(for videoIds: [String], completion: @escaping ([String: String]) -> Void) {
        guard !apiKey.isEmpty, !videoIds.isEmpty else {
            completion([:])
            return
        }

        let url = "https://www.googleapis.com/youtube/v3/videos?key=\(apiKey)&id=\(videoIds.joined(separator: ","))&part=contentDetails"

        guard let requestUrl = URL(string: url) else {
            completion([:])
            return
        }

        URLSession.shared.dataTask(with: requestUrl) { data, _, error in
            var durations: [String: String] = [:]
            if let data = data, let response = try? JSONDecoder().decode(YouTubeVideoDetailsResponse.self, from: data) {
                for item in response.items {
                    durations[item.id] = formatDuration(item.contentDetails.duration)
                }
            }
            DispatchQueue.main.async {
                completion(durations)
            }
        }.resume()
    }

    // Funkcija za formatiranje trajanja videa v format "mm:ss"
    func formatDuration(_ duration: String) -> String {
        let regex = try? NSRegularExpression(pattern: "PT(?:(\\d+)H)?(?:(\\d+)M)?(?:(\\d+)S)?", options: [])
        if let match = regex?.firstMatch(in: duration, options: [], range: NSRange(duration.startIndex..., in: duration)) {
            let hours = match.range(at: 1).location != NSNotFound ? (duration as NSString).substring(with: match.range(at: 1)) : "00"
            let minutes = match.range(at: 2).location != NSNotFound ? (duration as NSString).substring(with: match.range(at: 2)) : "00"
            let seconds = match.range(at: 3).location != NSNotFound ? (duration as NSString).substring(with: match.range(at: 3)) : "00"

            var result = ""
            if hours != "0" { result += "\(hours) h " }
            if minutes != "0" { result += "\(minutes) min " }
            if seconds != "0" { result += "\(seconds) s" }
            
            return result.trimmingCharacters(in: .whitespaces)
        }
        return "Neznana dolžina"
    }
}


// Modeli za dekodiranje JSON odgovora
struct YouTubeResponse: Codable {
    let items: [YouTubeVideo]
}

struct YouTubeVideo: Codable {
    let id: VideoID
    let snippet: Snippet
}

struct VideoID: Codable {
    let videoId: String?
}

struct Snippet: Codable {
    let title: String
    let publishedAt: String
    let channelTitle: String
    let description: String
}

struct YouTubeVideoDetailsResponse: Codable {
    let items: [YouTubeVideoDetails]
}

struct YouTubeVideoDetails: Codable {
    let id: String
    let contentDetails: ContentDetails
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
    let channelName: String
    var duration: String
    let publishedAt: String
    let description: String
}

// Pogled za prikaz videov
struct VideoView: View {
    var video: Video

    var body: some View {
        VStack {
            WebView(url: URL(string: "https://www.youtube-nocookie.com/embed/\(video.id)?rel=0&modestbranding=1&controls=1&showinfo=0&iv_load_policy=3&fs=1")!)
                .frame(height: 200)
            
            Text(video.title)
                .font(.caption)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
            
            // Prikaz dolžine videa
            Text(video.duration)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
        .padding()
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
