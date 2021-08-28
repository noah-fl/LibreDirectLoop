//
//  ContentView.swift
//  LibreDirect
//
//  Created by Reimar Metzen on 06.07.21.
//

import SwiftUI

typealias LibreDirectViewCompletionHandler = () -> Void

struct LibreDirectView: View {
    var doneCompletionHandler: LibreDirectViewCompletionHandler?
    var deleteCompletionHandler: LibreDirectViewCompletionHandler?
    
    @EnvironmentObject var store: AppStore

    var deleteButton: some View {
        Button(action: { deleteCompletionHandler?() }) { Text("Delete").bold() }
    }
    
    var doneButton: some View {
        Button(action: { doneCompletionHandler?() }) { Text("Done").bold() }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                AlarmSnoozeView().padding([.horizontal])
                
                ConnectionView(connectionState: store.state.connectionState, connectionError: store.state.connectionError, connectionErrorTimestamp: store.state.connectionErrorTimeStamp).padding([.top, .horizontal])
                LifetimeView(sensor: store.state.sensor).padding([.top, .horizontal])
                DetailsView(sensor: store.state.sensor).padding([.top, .horizontal])
                InternalsView(sensor: store.state.sensor).padding([.top, .horizontal])

                AlarmSettingsView().padding([.top, .horizontal])
                ActionsView().padding([.top, .horizontal])
            }
        }
        .navigationBarItems(leading: deleteButton, trailing: doneButton)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let store = AppStore(initialState: PreviewAppState())

        ForEach(ColorScheme.allCases, id: \.self) {
            LibreDirectView().environmentObject(store).preferredColorScheme($0)
        }
    }
}
