#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Arabic Morphological Analyzer Tester
Tests different libraries for Arabic root extraction
"""

import sys
from typing import Dict, List, Optional

class MorphologyTester:
    def __init__(self):
        self.results = {}
        self.available_libraries = []
        
    def test_farasa(self, words: List[str]) -> Dict[str, str]:
        """Test Farasa stemmer"""
        results = {}
        try:
            # Try different import paths for Farasa
            try:
                from farasa.stemmer import FarasaStemmer
                stemmer = FarasaStemmer()
            except ImportError:
                # Try alternative import
                import farasa
                # Farasa 0.0.1 might have different structure
                print("✗ Farasa structure not recognized. Version may be incompatible.")
                results = {word: "NOT_AVAILABLE" for word in words}
                return results
            
            print("✓ Farasa loaded successfully")
            
            for word in words:
                try:
                    root = stemmer.stem(word)
                    results[word] = root
                except Exception as e:
                    results[word] = f"ERROR: {str(e)}"
            
            self.available_libraries.append("Farasa")
        except ImportError:
            print("✗ Farasa not installed. Install with: pip install farasa")
            results = {word: "NOT_AVAILABLE" for word in words}
        except Exception as e:
            print(f"✗ Farasa error: {str(e)}")
            results = {word: f"ERROR: {str(e)}" for word in words}
        
        return results
    
    def test_camel_tools(self, words: List[str]) -> Dict[str, str]:
        """Test CAMeL Tools morphological analyzer"""
        results = {}
        try:
            from camel_tools.morphology.database import MorphologyDB
            from camel_tools.morphology.analyzer import Analyzer
            
            # Try to load the analyzer
            try:
                db = MorphologyDB.builtin_db()
                analyzer = Analyzer(db)
                print("✓ CAMeL Tools loaded successfully")
                
                for word in words:
                    try:
                        analyses = analyzer.analyze(word)
                        if analyses:
                            # Get the root from the first analysis
                            root = analyses[0].get('root', 'N/A')
                            results[word] = root
                        else:
                            results[word] = "NO_ANALYSIS"
                    except Exception as e:
                        results[word] = f"ERROR: {str(e)}"
            except Exception as e:
                print(f"✗ CAMeL Tools database error: {str(e)}")
                print("  Note: You may need to download the database separately")
                results = {word: "DB_ERROR" for word in words}
                
            self.available_libraries.append("CAMeL Tools")
        except ImportError:
            print("✗ CAMeL Tools not installed. Install with: pip install camel-tools")
            results = {word: "NOT_AVAILABLE" for word in words}
        except Exception as e:
            print(f"✗ CAMeL Tools error: {str(e)}")
            results = {word: f"ERROR: {str(e)}" for word in words}
        
        return results
    
    def test_pyarabic(self, words: List[str]) -> Dict[str, str]:
        """Test PyArabic stemmer"""
        results = {}
        try:
            import pyarabic.araby as araby
            
            # Try different PyArabic methods
            print("✓ PyArabic loaded successfully")
            
            for word in words:
                try:
                    # PyArabic doesn't have a direct stemmer in older versions
                    # Use basic normalization as fallback
                    normalized = araby.strip_tashkeel(word)
                    normalized = araby.normalize_hamza(normalized)
                    # Simple approach: remove common prefixes/suffixes
                    if normalized.startswith('ال'):
                        normalized = normalized[2:]
                    if normalized.endswith('ة'):
                        normalized = normalized[:-1] + 'ه'
                    results[word] = normalized
                except Exception as e:
                    results[word] = f"ERROR: {str(e)}"
            
            self.available_libraries.append("PyArabic")
        except ImportError:
            print("✗ PyArabic not installed. Install with: pip install pyarabic")
            results = {word: "NOT_AVAILABLE" for word in words}
        except Exception as e:
            print(f"✗ PyArabic error: {str(e)}")
            results = {word: f"ERROR: {str(e)}" for word in words}
        
        return results
    
    def test_isri_stemmer(self, words: List[str]) -> Dict[str, str]:
        """Test ISRI Stemmer (if available)"""
        results = {}
        try:
            # Try to import ISRI stemmer
            # Note: There might be different implementations
            from isri import ISRIStemmer
            
            stemmer = ISRIStemmer()
            print("✓ ISRI Stemmer loaded successfully")
            
            for word in words:
                try:
                    root = stemmer.stem(word)
                    results[word] = root
                except Exception as e:
                    results[word] = f"ERROR: {str(e)}"
            
            self.available_libraries.append("ISRI Stemmer")
        except ImportError:
            print("✗ ISRI Stemmer not installed or not available")
            results = {word: "NOT_AVAILABLE" for word in words}
        except Exception as e:
            print(f"✗ ISRI Stemmer error: {str(e)}")
            results = {word: f"ERROR: {str(e)}" for word in words}
        
        return results
    
    def run_all_tests(self, words: List[str]) -> Dict[str, Dict[str, str]]:
        """Run all available tests"""
        print("=" * 60)
        print("Arabic Morphological Analyzer Tester")
        print("=" * 60)
        print(f"\nTesting {len(words)} words: {', '.join(words)}\n")
        
        all_results = {}
        
        # Test each library
        print("\n[1] Testing Farasa...")
        all_results['Farasa'] = self.test_farasa(words)
        
        print("\n[2] Testing CAMeL Tools...")
        all_results['CAMeL Tools'] = self.test_camel_tools(words)
        
        print("\n[3] Testing PyArabic...")
        all_results['PyArabic'] = self.test_pyarabic(words)
        
        print("\n[4] Testing ISRI Stemmer...")
        all_results['ISRI Stemmer'] = self.test_isri_stemmer(words)
        
        return all_results
    
    def print_results(self, results: Dict[str, Dict[str, str]]):
        """Print results in a formatted table"""
        print("\n" + "=" * 60)
        print("RESULTS")
        print("=" * 60)
        
        # Get all words
        all_words = set()
        for lib_results in results.values():
            all_words.update(lib_results.keys())
        
        # Print header
        print(f"\n{'Word':<15}", end="")
        for lib_name in results.keys():
            print(f"{lib_name:<20}", end="")
        print()
        print("-" * 60)
        
        # Print results for each word
        for word in sorted(all_words):
            print(f"{word:<15}", end="")
            for lib_name in results.keys():
                root = results[lib_name].get(word, "N/A")
                print(f"{root:<20}", end="")
            print()
        
        print("\n" + "=" * 60)
        print(f"Available libraries: {', '.join(self.available_libraries)}")
        print("=" * 60)


def main():
    # Test words
    test_words = [
        "دعونا",
        "دعوت",
        "الدعوات",
        "ادعاء",
        "المحاماة",
        "كاتب",
        "قراءة",
        "قرأ",
        "مقرأة",
        "دعا",
        "مزار",
    ]
    
    # Allow custom words from command line
    if len(sys.argv) > 1:
        test_words = sys.argv[1:]
    
    tester = MorphologyTester()
    results = tester.run_all_tests(test_words)
    tester.print_results(results)
    
    # Interactive mode
    print("\n" + "=" * 60)
    print("Interactive Mode")
    print("=" * 60)
    print("Enter words to test (one per line, or 'quit' to exit):")
    
    while True:
        try:
            word = input("\nWord: ").strip()
            if word.lower() in ['quit', 'exit', 'q']:
                break
            if word:
                results = tester.run_all_tests([word])
                tester.print_results(results)
        except KeyboardInterrupt:
            print("\n\nExiting...")
            break
        except EOFError:
            break


if __name__ == "__main__":
    main()

