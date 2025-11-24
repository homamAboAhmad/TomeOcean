#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Flask API Server for Arabic Morphological Analysis
Can be called from Flutter app
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
from test_morphology import MorphologyTester
import traceback

app = Flask(__name__)
CORS(app)  # Enable CORS for Flutter app

tester = MorphologyTester()

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'ok',
        'available_libraries': tester.available_libraries
    })

@app.route('/analyze', methods=['POST'])
def analyze():
    """Analyze a single word"""
    try:
        data = request.get_json()
        word = data.get('word', '')
        
        if not word:
            return jsonify({'error': 'Word is required'}), 400
        
        results = {}
        
        # Test each library
        if 'Farasa' in tester.available_libraries:
            farasa_results = tester.test_farasa([word])
            results['Farasa'] = farasa_results.get(word, 'N/A')
        
        if 'CAMeL Tools' in tester.available_libraries:
            camel_results = tester.test_camel_tools([word])
            results['CAMeL Tools'] = camel_results.get(word, 'N/A')
        
        if 'PyArabic' in tester.available_libraries:
            pyarabic_results = tester.test_pyarabic([word])
            results['PyArabic'] = pyarabic_results.get(word, 'N/A')
        
        return jsonify({
            'word': word,
            'results': results
        })
    
    except Exception as e:
        return jsonify({
            'error': str(e),
            'traceback': traceback.format_exc()
        }), 500

@app.route('/analyze_batch', methods=['POST'])
def analyze_batch():
    """Analyze multiple words"""
    try:
        data = request.get_json()
        words = data.get('words', [])
        
        if not words:
            return jsonify({'error': 'Words list is required'}), 400
        
        all_results = tester.run_all_tests(words)
        
        return jsonify({
            'words': words,
            'results': all_results
        })
    
    except Exception as e:
        return jsonify({
            'error': str(e),
            'traceback': traceback.format_exc()
        }), 500

@app.route('/get_root', methods=['POST'])
def get_root():
    """Get root using the best available library (Farasa preferred)"""
    try:
        data = request.get_json()
        word = data.get('word', '')
        preferred_lib = data.get('library', 'Farasa')  # Default to Farasa
        
        if not word:
            return jsonify({'error': 'Word is required'}), 400
        
        # Try preferred library first
        if preferred_lib == 'Farasa' and 'Farasa' in tester.available_libraries:
            results = tester.test_farasa([word])
            root = results.get(word, None)
            if root and root != 'NOT_AVAILABLE' and not root.startswith('ERROR'):
                return jsonify({
                    'word': word,
                    'root': root,
                    'library': 'Farasa'
                })
        
        # Try CAMeL Tools
        if 'CAMeL Tools' in tester.available_libraries:
            results = tester.test_camel_tools([word])
            root = results.get(word, None)
            if root and root != 'NOT_AVAILABLE' and root != 'DB_ERROR' and not root.startswith('ERROR'):
                return jsonify({
                    'word': word,
                    'root': root,
                    'library': 'CAMeL Tools'
                })
        
        # Try PyArabic as fallback
        if 'PyArabic' in tester.available_libraries:
            results = tester.test_pyarabic([word])
            root = results.get(word, None)
            if root and root != 'NOT_AVAILABLE' and not root.startswith('ERROR'):
                return jsonify({
                    'word': word,
                    'root': root,
                    'library': 'PyArabic'
                })
        
        return jsonify({
            'error': 'No available library could analyze this word'
        }), 404
    
    except Exception as e:
        return jsonify({
            'error': str(e),
            'traceback': traceback.format_exc()
        }), 500

if __name__ == '__main__':
    print("=" * 60)
    print("Arabic Morphology API Server")
    print("=" * 60)
    print("\nStarting server on http://localhost:5000")
    print("Available endpoints:")
    print("  GET  /health - Check server status")
    print("  POST /analyze - Analyze a single word")
    print("  POST /analyze_batch - Analyze multiple words")
    print("  POST /get_root - Get root (best library)")
    print("\nExample usage:")
    print('  curl -X POST http://localhost:5000/get_root -H "Content-Type: application/json" -d \'{"word": "محاماة"}\'')
    print("\n" + "=" * 60 + "\n")
    
    app.run(host='0.0.0.0', port=5000, debug=True)

