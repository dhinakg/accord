//
//  ContentView.swift
//  Accord
//
//  Created by evelyn on 2020-11-24.
//

import SwiftUI
import Combine

// Discord WebSocket
var wss: Gateway!

struct ContentView: View {
    @State var modalIsPresented: Bool = false
    @State var wsCancellable = Set<AnyCancellable>()
    @Binding var loaded: Bool
    @State var serverListView: ServerListView?

    enum LoadErrors: Error {
        case alreadyLoaded
    }

    var body: some View {
        Group {
            if modalIsPresented {
                LoginView()
            } else if !loaded {
                LoadingView()
            } else {
                serverListView
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 20, execute: {
                wss.reset()
            })
            concurrentQueue.async {
                guard AccordCoreVars.token != "" else { modalIsPresented = true; return }
                do {
                    guard wss == nil else {
                        throw LoadErrors.alreadyLoaded
                    }
                    let new = try Gateway.init(url: Gateway.gatewayURL)
                    print("init")
                    wss = new
                    wss.ready()
                        .sink(receiveCompletion: { completion in
                            switch completion {
                            case .finished:
                                break
                            case .failure(let error):
                                print(error)
                                break
                            }
                        }, receiveValue: { d in

                            AccordCoreVars.user = d.user
                            user_id = d.user.id
                            if let pfp = d.user.avatar {
                                Request.fetch(url: URL(string: "https://cdn.discordapp.com/avatars/\(d.user.id)/\(pfp).png?size=80")) { avatar = $0 ?? Data(); _ = $1 }
                            }
                            username = d.user.username
                            discriminator = d.user.discriminator
                            self.serverListView = ServerListView(full: d)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                                withAnimation {
                                    loaded = true
                                }
                            })
                        })
                        .store(in: &wsCancellable)
                } catch {
                    print(error)
                    let path = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("socketOut.json")
                    do {
                        let data = try Data(contentsOf: path)
                        let structure = try JSONDecoder().decode(GatewayStructure.self, from: data)
                        self.serverListView = ServerListView(full: structure.d)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                            withAnimation {
                                loaded = true
                            }
                        })
                    } catch {
                        print(error)
                    }
                }
            }
        }
    }
}