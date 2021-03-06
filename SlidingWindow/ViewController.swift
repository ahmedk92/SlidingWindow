//
//  ViewController.swift
//  Prefetched
//
//  Created by Ahmed Khalaf on 5/24/19.
//  Copyright © 2019 Ahmed Khalaf. All rights reserved.
//

import UIKit

class Cell: UITableViewCell {
    @IBOutlet var label: UILabel!
}

struct MyData: ElementType {
    let id: Int
    let string: String
}

class ViewController: UIViewController {
    @IBOutlet private weak var tableView: UITableView!
    
    @IBOutlet private weak var nextButton: UIButton!
    @IBOutlet private weak var prevButton: UIButton!
    
    @IBOutlet private weak var jumpButton: UIButton!
    var jumpIndex = 0
    private let step = 10
    var currentIndex = 0 {
        didSet {
            nextButton.setTitle("Forward to \(currentIndex + step)", for: .normal)
            prevButton.setTitle("Backward to \(currentIndex - step)", for: .normal)
        }
    }
    
    @IBAction private func jumpButtonTapped(_ sender: UIButton) {
        tableView.scrollToRow(at: IndexPath(row: jumpIndex, section: 0), at: .top, animated: false)
        currentIndex = jumpIndex
        jumpIndex = (0..<ids.count).randomElement()!
        jumpButton.setTitle("Jump to \(jumpIndex)", for: .normal)
    }
        
    @IBAction private func nextButtonTapped(_ sender: UIButton) {
        guard currentIndex + step < ids.count else { return }
        tableView.scrollToRow(at: IndexPath(row: currentIndex + step, section: 0), at: .top, animated: true)
        currentIndex += step
    }
    @IBAction private func prevButtonTapped(_ sender: UIButton) {
        guard currentIndex - step >= 0 else { return }
        tableView.scrollToRow(at: IndexPath(row: currentIndex - step, section: 0), at: .top, animated: true)
        currentIndex -= step
    }
    
    private let ids = Array(0...10000)
    
    private lazy var dataWindow = DataWindow<MyData>(ids: ids, windowSize: 50, dataFetcher: { (ids) in
        Thread.sleep(forTimeInterval: TimeInterval((2...10).randomElement()!) / 10) // Simulate Heavy Work
        return ids.map({ MyData(id: $0, string: "\($0) \(randomText(length: Int.random(in: 100...1000)))") })
    }, errorHandler: { error in
        print(error)
    }, onElementsReadyHandler: {
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    })
    
    override func viewDidLoad() {
        super.viewDidLoad()
        jumpButtonTapped(jumpButton)
    }
        
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
//        tableView.scrollToRow(at: IndexPath(row: 5000, section: 0), at: .top, animated: false)
    }
}

extension ViewController: UITableViewDataSource, UITableViewDataSourcePrefetching {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataWindow.ids.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! Cell
        cell.label.text = dataWindow[indexPath.row, block: true]?.string
        return cell
    }
    
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        for indexPath in indexPaths {
            let peek = 10
            let indicesToPrefetch = [indexPath.row + peek, indexPath.row - peek]
            for indexToPrefetch in indicesToPrefetch {
                print("Will prefetch \(indexToPrefetch)")
                dataWindow.prefetch(index: indexToPrefetch)
            }
        }
    }
}

//extension ViewController: UITableViewDelegate {
//    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
//        return 50
//    }
//}

// Credits: https://gist.github.com/skreutzberger/eac3edc7918d0251f366
func randomText(length: Int, justLowerCase: Bool = false) -> String {
    var text = ""
    for _ in 1...length {
        var decValue = 0  // ascii decimal value of a character
        var charType = 3  // default is lowercase
        if justLowerCase == false {
            // randomize the character type
            charType =  Int(arc4random_uniform(4))
        }
        switch charType {
        case 1:  // digit: random Int between 48 and 57
            decValue = Int(arc4random_uniform(10)) + 48
        case 2:  // uppercase letter
            decValue = Int(arc4random_uniform(26)) + 65
        case 3:  // lowercase letter
            decValue = Int(arc4random_uniform(26)) + 97
        default:  // space character
            decValue = 32
        }
        // get ASCII character from random decimal value
        let char = String(UnicodeScalar(decValue)!)
        text = text + char
        // remove double spaces
        text = text.replacingOccurrences(of: "  ", with: " ")
    }
    return text
}

