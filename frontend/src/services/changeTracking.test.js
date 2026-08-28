import { describe, expect, it } from 'vitest'
import { hasChanges, snapshot } from './changeTracking'

describe('change tracking', () => {
  it('ignores object key and permission array order', () => {
    const original = snapshot({ name: 'Editor', permission_keys: ['users.view', 'dashboard.view'] })
    expect(hasChanges({ permission_keys: ['dashboard.view', 'users.view'], name: 'Editor' }, original)).toBe(false)
  })

  it('detects a changed field', () => {
    const original = snapshot({ role: 'member', active: true })
    expect(hasChanges({ role: 'editor', active: true }, original)).toBe(true)
  })
})
