//
//  NIP06DebugTests.swift
//  CoreNostrTests
//
//  Debug tests for NIP-06
//

import Testing
@testable import CoreNostr
import Foundation

@Suite("NIP-06 Debug Tests")
struct NIP06DebugTests {
    
    @Test("Test deterministic derivation")
    func testDeterministicDerivation() throws {
        let testMnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        
        // print("Test mnemonic: \(testMnemonic)")
        
        // Derive multiple times
        for i in 1...3 {
            // print("\nDerivation \(i):")
            
            // Get seed
            let seed = try BIP39.mnemonicToSeed(testMnemonic)
            // print("Seed: \(seed.hex)")
            
            // Create master key
            let masterKey = try BIP32.createMasterKey(from: seed)
            // print("Master key: \(masterKey.key.hex)")
            // print("Master chain code: \(masterKey.chainCode.hex)")
            
            // Derive path m/44'/1237'/0'/0'/0'
            let keyPair = try NIP06.deriveKeyPair(from: testMnemonic)
            // print("Final private key: \(keyPair.privateKey)")
            // print("Final public key: \(keyPair.publicKey)")
        }
    }
    
    @Test("Test BIP32 derivation step by step")
    func testBIP32StepByStep() throws {
        let testMnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        let seed = try BIP39.mnemonicToSeed(testMnemonic)
        
        // print("Starting BIP32 derivation")
        // print("Seed: \(seed.hex)")
        
        let master = try BIP32.createMasterKey(from: seed)
        // print("\nMaster key:")
        // print("  Private: \(master.key.hex)")
        // print("  Chain code: \(master.chainCode.hex)")
        
        // m/44'
        let purpose = try BIP32.deriveChild(master, index: 44 + 0x80000000)
        // print("\nm/44':")
        // print("  Private: \(purpose.key.hex)")
        // print("  Chain code: \(purpose.chainCode.hex)")
        
        // m/44'/1237'
        let coinType = try BIP32.deriveChild(purpose, index: 1237 + 0x80000000)
        // print("\nm/44'/1237':")
        // print("  Private: \(coinType.key.hex)")
        // print("  Chain code: \(coinType.chainCode.hex)")
        
        // m/44'/1237'/0'
        let account = try BIP32.deriveChild(coinType, index: 0 + 0x80000000)
        // print("\nm/44'/1237'/0':")
        // print("  Private: \(account.key.hex)")
        // print("  Chain code: \(account.chainCode.hex)")
        
        // m/44'/1237'/0'/0'
        let change = try BIP32.deriveChild(account, index: 0 + 0x80000000)
        // print("\nm/44'/1237'/0'/0':")
        // print("  Private: \(change.key.hex)")
        // print("  Chain code: \(change.chainCode.hex)")
        
        // m/44'/1237'/0'/0'/0'
        let addressKey = try BIP32.deriveChild(change, index: 0 + 0x80000000)
        // print("\nm/44'/1237'/0'/0'/0':")
        // print("  Private: \(addressKey.key.hex)")
        // print("  Chain code: \(addressKey.chainCode.hex)")
        
        // Create key pair
        let keyPair = try KeyPair(privateKey: addressKey.key.hex)
        // print("\nFinal key pair:")
        // print("  Private: \(keyPair.privateKey)")
        // print("  Public: \(keyPair.publicKey)")
    }
    
    @Test("Test generateKeyPair")
    func testGenerateKeyPair() throws {
        // print("Testing NIP06.generateKeyPair()")
        
        let (mnemonic, keyPair) = try NIP06.generateKeyPair()
        // print("Generated mnemonic: \(mnemonic)")
        // print("Generated private key: \(keyPair.privateKey)")
        // print("Generated public key: \(keyPair.publicKey)")
        
        // print("\nNow deriving from the same mnemonic...")
        let derivedKeyPair = try NIP06.deriveKeyPair(from: mnemonic)
        // print("Derived private key: \(derivedKeyPair.privateKey)")
        // print("Derived public key: \(derivedKeyPair.publicKey)")
        
        // print("\nKeys match: \(keyPair.privateKey == derivedKeyPair.privateKey)")
    }
}