import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import DataTable from './DataTable.vue'

const items = Array.from({ length: 12 }, (_, index) => ({ id: index + 1, name: `User ${index + 1}` }))
const columns = [{ key: 'name', label: 'Name' }]

describe('DataTable', () => {
  it('blocks the table and shows a spinner while loading', () => {
    const wrapper = mount(DataTable, { props: { items: [], columns, loading: true } })
    expect(wrapper.attributes('aria-busy')).toBe('true')
    expect(wrapper.find('[role="status"]').exists()).toBe(true)
    expect(wrapper.find('.animate-spin').exists()).toBe(true)
  })

  it('searches, sorts, changes page size, and paginates locally', async () => {
    const wrapper = mount(DataTable, { props: { items, columns, searchKeys: ['name'] } })
    await wrapper.find('select').setValue('5')
    expect(wrapper.findAll('tbody tr')).toHaveLength(5)

    await wrapper.findAll('button').at(-1).trigger('click')
    expect(wrapper.text()).toContain('2 / 3')

    await wrapper.find('input[type="search"]').setValue('User 12')
    expect(wrapper.findAll('tbody tr')).toHaveLength(1)
    expect(wrapper.text()).toContain('User 12')
  })
})
