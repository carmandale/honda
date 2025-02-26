//
//  for.swift
//  honda
//
//  Created by Dale Carman on 2/26/25.
//


//
//  AttackCancerViewerButton.swift
//  SpawnAndAttrack
//
//  Created by Dale Carman on 12/13/24.
//

import SwiftUI

// Color theme enum for testing different combinations
enum GradientTheme: CaseIterable {
    case darkRed
    case lightRed
    case lightGreen
    case lightMustard
    case lightBlue
    
    var colors: [Color] {
        switch self {
        case .darkRed:
            return [
                Color("DarkRed800"),
                Color("DarkRed600"),
                Color("DarkRed400"),
                Color("DarkRed200"),
                Color("DarkRed050")
            ]
        case .lightRed:
            return [
                Color("LightRed800"),
                Color("LightRed600"),
                Color("LightRed400"),
                Color("LightRed200"),
                Color("LightRed050")
            ]
        case .lightGreen:
            return [
                Color("LightGreen800"),
                Color("LightGreen600"),
                Color("LightGreen400"),
                Color("LightGreen200"),
                Color("LightGreen050")
            ]
        case .lightMustard:
            return [
                Color("LightMustard800"),
                Color("LightMustard600"),
                Color("LightMustard400"),
                Color("LightMustard200"),
                Color("LightMustard050")
            ]
        case .lightBlue:
            return [
                Color("LightBlue800"),
                Color("LightBlue600"),
                Color("LightBlue400"),
                Color("LightBlue200"),
                Color("LightBlue050")
            ]
        }
    }
}



//#Preview {
//    AttackCancerViewerButton()
//}
