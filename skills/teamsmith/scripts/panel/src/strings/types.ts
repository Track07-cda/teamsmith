// The shape every language table satisfies.
//
// A flat `key → string` map is deliberate: the key-set assertion (`tests/panel-strings.mjs`) is a
// plain set comparison, the placeholder check is a token comparison, and the layout can substitute
// with `fill()`. Values carry `{placeholders}`; both tables must use the same ones per key.

export interface Strings {
  readonly [key: string]: string
}
