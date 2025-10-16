//
//  AlignedLabel.swift
//  X2D GPS Companion
//
//  Created by qaq on 18/10/2025.
//

import SwiftUI

struct AlignedLabel: View {
    let icon: String
    let text: LocalizedStringKey

    var body: some View {
        HStack {
            Image(systemName: "circle")
                .font(.body)
                .hidden()
                .overlay {
                    Image(systemName: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            Text(text)
                .font(.body)
        }
    }
}

#Preview {
    AlignedLabel(icon: "photo.on.rectangle", text: "PHOTO_ACCESS")
}
