import { describe, expect, it } from 'vitest'
import { reportContext } from './reportContext'
describe('reportContext', () => {
  it('defaults to seven UTC days with equal previous period', () => {
    expect(reportContext({}, '2026-03-07')).toEqual({ start_date: '2026-03-01', end_date: '2026-03-07', days: 7, previous_start: '2026-02-22', previous_end: '2026-02-28' })
  })
  it('preserves valid shareable ranges and normalizes invalid or oversized ranges', () => {
    const range = reportContext({ start_date: '2026-02-28', end_date: '2026-03-01' }, '2026-03-07')
    expect(range.days).toBe(2)
    for (const query of [ { start_date: '2026-02-30' }, { start_date: ['2026-03-01'] }, { start_date: '2020-01-01' }, { start_date: '2026-03-08' }, { end_date: '2027-03-01' }, { start_date: 'x' } ]) {
      expect(reportContext(query, '2026-03-07')).toEqual(reportContext({}, '2026-03-07'))
    }
  })
})
