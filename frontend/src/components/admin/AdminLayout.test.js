import { mount } from '@vue/test-utils'
import { nextTick } from 'vue'
import { describe, expect, it, vi } from 'vitest'
import AdminLayout from './AdminLayout.vue'

vi.mock('vue-router', () => ({ useRoute: () => ({ path: '/admin' }) }))

function mountLayout() {
  return mount(AdminLayout, {
    props: { email: 'admin@example.com' },
    global: {
      stubs: {
        RouterLink: { template: '<a><slot /></a>' },
      },
    },
  })
}

describe('AdminLayout', () => {
  it('collapses the desktop sidebar to an icon rail and persists the choice', async () => {
    const wrapper = mountLayout()

    await wrapper.get('[aria-label="Kecilkan sidebar"]').trigger('click')

    expect(wrapper.get('aside').classes()).toContain('lg:w-[90px]')
    expect(wrapper.get('[aria-label="Lebarkan sidebar"]').exists()).toBe(true)
    expect(localStorage.getItem('tourplan-sidebar')).toBe('closed')
  })

  it('restores the collapsed sidebar preference', async () => {
    localStorage.setItem('tourplan-sidebar', 'closed')
    const wrapper = mountLayout()
    await nextTick()

    expect(wrapper.get('aside').classes()).toContain('lg:w-[90px]')
  })
})
