import Foundation

extension String {

    func lpad(_ length: Int, _ pad: Character = " ") -> String {
        let selfLength = self.count
        guard selfLength < length else { return self }
        return String(repeating: pad, count: length - selfLength) + self
    }

    func rpad(_ length: Int, _ pad: Character = " ") -> String {
        let selfLength = self.count
        guard selfLength < length else { return self }
        return self + String(repeating: pad, count: length - selfLength)
    }
}
