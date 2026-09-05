import { semanticToneClasses } from "@/lib/uiTones";

const typeToneClasses: Record<string, string> = {
    Normal: semanticToneClasses.stone,
    Grass: semanticToneClasses.emerald,
    Fire: semanticToneClasses.orange,
    Water: semanticToneClasses.blue,
    Light: semanticToneClasses.yellow,
    Ground: semanticToneClasses.amber,
    Ice: semanticToneClasses.cyan,
    Dragon: semanticToneClasses.red,
    Electric: semanticToneClasses.yellow,
    Poison: semanticToneClasses.purple,
    Bug: semanticToneClasses.lime,
    Fighting: semanticToneClasses.orange,
    Flying: semanticToneClasses.sky,
    Cute: semanticToneClasses.pink,
    Ghost: semanticToneClasses.indigo,
    Dark: semanticToneClasses.rose,
    Mechanical: semanticToneClasses.emerald,
    Illusion: semanticToneClasses.violet,
    Leader: semanticToneClasses.slate,
};

export function getTypeToneClasses(typeName: string) {
    return typeToneClasses[typeName] ?? semanticToneClasses.slate;
}
