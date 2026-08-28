import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import AsyncButton from './AsyncButton.vue'

describe('AsyncButton', () => {
  it('disables the button and shows loading feedback', () => {
    const wrapper = mount(AsyncButton, { props: { loading: true, loadingText: 'Menyimpan…' }, slots: { default: 'Simpan' } })

    expect(wrapper.get('button').attributes()).toMatchObject({ disabled: '', 'aria-busy': 'true' })
    expect(wrapper.text()).toBe('Menyimpan…')
    expect(wrapper.find('svg').exists()).toBe(true)
  })

  it('renders its regular label when idle', () => {
    const wrapper = mount(AsyncButton, { slots: { default: 'Simpan' } })
    expect(wrapper.text()).toBe('Simpan')
    expect(wrapper.get('button').attributes('aria-busy')).toBe('false')
  })
})
