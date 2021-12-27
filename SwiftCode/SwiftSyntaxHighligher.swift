//
//  SwiftSyntaxHighligher.swift
//  SwiftCode
//
//  Created by Vlad Gorlov on 27.12.21.
//  Copyright © 2021 Benedikt Terhechte. All rights reserved.
//

import Foundation

class SwiftSyntaxHighligher: SyntaxHighligher {

    override func completionChars() -> [Character] {
        // return the only char for which we offer completion right now
        return [Character.init(".")]
    }

    override func reservedMatchers() -> [String] {
        return [ "COMMENT", "/\\*(?s:.)*?(?:\\*/|\\z)",
                 "COMMENT", "//.*",
                 "QUOTES",  "(?ms:\"{3}(?!\\\"{1,3}).*?(?:\"{3}|\\z))|(?:\"{1}(?!\\\").*?(?:\"|\\Z))",
                 "SINGLE_QUOTES", "(?ms:'{3}(?!'{1,3}).*?(?:'{3}|\\z))|(?:'[^'].*?(?:'|\\z))",
                 "DIGIT", "(?<=\\b)(?:0x)?\\d+[efld]?",
                 "OPERATION", "[\\w\\$&&[\\D]][\\w\\$]* *\\("]
    }

    override func reservedWords() -> [String] {
        return ["(?:\\bclass\\b)", "(?:\\bdeinit\\b)", "(?:\\benum\\b)", "(?:\\bextension\\b)", "(?:\\bfunc\\b)", "(?:\\bimport\\b)", "(?:\\binit\\b)", "(?:\\binternal\\b)", "(?:\\blet\\b)", "(?:\\boperator\\b)", "(?:\\bprivate\\b)", "(?:\\bprotocol\\b)", "(?:\\bpublic\\b)", "(?:\\bstatic\\b)", "(?:\\bstruct\\b)", "(?:\\bsubscript\\b)", "(?:\\btypealias\\b)", "(?:\\bvar\\b)", "(?:\\bbreak\\b)", "(?:\\bcase\\b)", "(?:\\bcontinue\\b)", "(?:\\bdefault\\b)", "(?:\\bdo\\b)", "(?:\\belse\\b)", "(?:\\bfallthrough\\b)", "(?:\\bfor\\b)", "(?:\\bif\\b)", "(?:\\bin\\b)", "(?:\\breturn\\b)", "(?:\\bswitch\\b)", "(?:\\bwhere\\b)", "(?:\\bwhile\\b)", "(?:\\bas\\b)", "(?:\\bdynamicType\\b)", "(?:\\bfalse\\b)", "(?:\\bis\\b)", "(?:\\bnil\\b)", "(?:\\bself\\b)", "(?:\\bSelf\\b)", "(?:\\bsuper\\b)", "(?:\\btrue\\b)", "(?:\\b__COLUMN__\\b)", "(?:\\b__FILE__\\b)", "(?:\\b__FUNCTION__\\b)", "(?:\\b__LINE__\\b)", "(?:\\bassociativity\\b)", "(?:\\bconvenience\\b)", "(?:\\bdynamic\\b)", "(?:\\bdidSet\\b)", "(?:\\bfinal\\b)", "(?:\\bget\\b)", "(?:\\binfix\\b)", "(?:\\binout\\b)", "(?:\\blazy\\b)", "(?:\\bleft\\b)", "(?:\\bmutating\\b)", "(?:\\bnone\\b)", "(?:\\bnonmutating\\b)", "(?:\\boptional\\b)", "(?:\\boverride\\b)", "(?:\\bpostfix\\b)", "(?:\\bprecedence\\b)", "(?:\\bprefix\\b)", "(?:\\bProtocol\\b)", "(?:\\brequired\\b)", "(?:\\bright\\b)", "(?:\\bset\\b)", "(?:\\bType\\b)", "(?:\\bunowned\\b)", "(?:\\bweak\\b)", "(?:\\bwillSet\\b)", "(?:\\bString\\b)", "(?:\\bInt\\b)", "(?:\\bInt32\\b)", "(?:\\bNSDate\\b)", "(?:\\bCGFloat\\b)", "(?:\\bDecoded\\b)", "(?:\\bArgo.decodable\\b)"];
    }
}
