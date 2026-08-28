function canonicalize(value) {
  if (Array.isArray(value)) return value.map(canonicalize).sort((left, right) => JSON.stringify(left).localeCompare(JSON.stringify(right)))
  if (value && typeof value === 'object') {
    return Object.keys(value).sort().reduce((result, key) => {
      result[key] = canonicalize(value[key])
      return result
    }, {})
  }
  return value
}

export function snapshot(value) {
  return JSON.stringify(canonicalize(value))
}

export function hasChanges(value, originalSnapshot) {
  return snapshot(value) !== originalSnapshot
}
