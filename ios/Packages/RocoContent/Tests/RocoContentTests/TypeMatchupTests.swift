import Foundation
import Testing
import RocoDomain
@testable import RocoContent

struct TypeMatchupTests {
    private func engine() throws -> TypeMatchup {
        let data = Data("""
        [
          {"typeId":1,"name":"a","nameZh":"甲","normalBattleType":true,"weakToTypeIds":[2],"resistToTypeIds":[3]},
          {"typeId":2,"name":"b","nameZh":"乙","normalBattleType":true,"weakToTypeIds":[2,3],"resistToTypeIds":[1]},
          {"typeId":3,"name":"c","nameZh":"丙","normalBattleType":true,"weakToTypeIds":[],"resistToTypeIds":[3]},
          {"typeId":4,"name":"Leader","nameZh":"首领","normalBattleType":false,"weakToTypeIds":[],"resistToTypeIds":[]}
        ]
        """.utf8)
        let rows = try JSONDecoder().decode([BattleType].self, from: data)
        return TypeMatchup(types: Dictionary(uniqueKeysWithValues: rows.map { ($0.typeId, $0) }))
    }
    @Test func multipliersAndUnion() throws {
        let e = try engine()
        let a = TypeID(rawValue: 1), b = TypeID(rawValue: 2), c = TypeID(rawValue: 3)
        #expect(try e.single(attack: b, defense: a) == 2)
        #expect(try e.single(attack: c, defense: a) == 0.5)
        #expect(try e.defense(attack: b, defenders: [a,b]) == 3)
        #expect(try e.defense(attack: a, defenders: [a,b]) == 0.5)
        #expect(try e.defense(attack: c, defenders: [a,b]) == 1)
        #expect(try e.defense(attack: c, defenders: [a,c]) == 0.25)
        #expect(try e.defense(attack: b, defenders: [a,a]) == 2)
        #expect(try e.coverage(attackers: [b,c,b]).map(\.typeId) == [a,b])
        #expect(e.selectable.count == 3)
    }
}
