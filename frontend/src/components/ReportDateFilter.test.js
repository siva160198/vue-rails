import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import ReportDateFilter from './ReportDateFilter.vue'
import { reportContext } from '../services/reportContext'
describe('ReportDateFilter', () => {
  it('avoids no-op submissions and explains invalid dates inline', async () => {
    const range = reportContext()
    const wrapper = mount(ReportDateFilter, { props: { range } })
    expect(wrapper.find('button').element.disabled).toBe(true)
    await wrapper.find('input[name="start_date"]').setValue('2020-01-01')
    await wrapper.find('form').trigger('submit')
    expect(wrapper.find('[role="alert"]').exists()).toBe(true)
    expect(wrapper.emitted('change')).toBeUndefined()
    await wrapper.find('input[name="start_date"]').setValue(range.end_date)
    await wrapper.find('form').trigger('submit')
    expect(wrapper.emitted('change')[0][0].start_date).toBe(range.end_date)
    await wrapper.setProps({ loading: true })
    await wrapper.find('form').trigger('submit')
    expect(wrapper.emitted('change')).toHaveLength(1)
    expect(wrapper.find('input').element.disabled).toBe(true)
  })
})
