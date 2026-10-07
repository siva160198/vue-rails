const DAY = 86400000
export function reportContext(query = {}, today = new Date().toISOString().slice(0, 10)) {
  const parse = value => {
    if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return null
    const date = new Date(`${value}T00:00:00Z`)
    return Number.isFinite(date.getTime()) && date.toISOString().slice(0, 10) === value ? date : null
  }
  const fallbackEnd = parse(today)
  let end = parse(query.end_date) || fallbackEnd
  let start = parse(query.start_date) || new Date(end.getTime() - 6 * DAY)
  let days = Math.round((end - start) / DAY) + 1
  if (days < 1 || days > 366 || end > fallbackEnd) {
    end = fallbackEnd; start = new Date(end.getTime() - 6 * DAY); days = 7
  }
  const format = value => value.toISOString().slice(0, 10)
  return {
    start_date: format(start), end_date: format(end), days,
    previous_start: format(new Date(start.getTime() - days * DAY)),
    previous_end: format(new Date(start.getTime() - DAY)),
  }
}
