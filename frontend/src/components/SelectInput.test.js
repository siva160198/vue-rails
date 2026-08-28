import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import SelectInput from './SelectInput.vue'

describe('SelectInput', () => {
  it('updates Vue v-model while preserving numeric values', async () => {
    const wrapper = mount(SelectInput, { props: { modelValue: 5, 'onUpdate:modelValue': (value) => wrapper.setProps({ modelValue: value }) }, slots: { default: '<option value="5">5</option><option value="10">10</option>' } })
    await wrapper.find('select').setValue('10')
    expect(wrapper.props('modelValue')).toBe(10)
  })
})
