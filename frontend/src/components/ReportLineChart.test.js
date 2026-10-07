import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import axe from 'axe-core'
import ReportLineChart from './ReportLineChart.vue'
describe('ReportLineChart', () => {
  it('supports loading empty and retry states', async () => {
    const wrapper = mount(ReportLineChart, { props: { title: 'Registrations', loading: true } })
    expect(wrapper.find('[role="status"]').exists()).toBe(true)
    expect(wrapper.attributes('aria-busy')).toBe('true')
    await wrapper.setProps({ loading: false })
    expect(wrapper.find('svg').exists()).toBe(false)
    await wrapper.setProps({ error: true })
    await wrapper.find('button').trigger('click')
    expect(wrapper.emitted('retry')).toHaveLength(1)
  })
  it('renders undistorted geometry with hover keyboard and touch disclosure', async () => {
    const wrapper = mount(ReportLineChart, { attachTo: document.body, props: { title: 'Registrations', current: [{ date: '2026-01-02', value: 2 }], previous: [{ date: '2026-01-01', value: 1 }] } })
    expect(wrapper.find('svg').attributes('preserveAspectRatio')).toBe('xMidYMid meet')
    const point = wrapper.find('circle')
    await point.trigger('mouseenter')
    expect(wrapper.find('[role="status"]').text()).toContain('2026-01-01')
    await point.trigger('mouseleave')
    expect(wrapper.find('[role="status"]').exists()).toBe(false)
    await point.trigger('focus')
    await point.trigger('blur')
    await point.trigger('click')
    await point.trigger('click')
    await point.trigger('keydown', { key: 'Enter' })
    await point.trigger('keydown', { key: ' ' })
    expect(wrapper.find('[role="status"]').text()).toContain('2026-01-02')
    expect((await axe.run(wrapper.element, { rules: { 'color-contrast': { enabled: false } } })).violations).toEqual([])
    wrapper.unmount()
  })
})
