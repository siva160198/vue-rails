import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import ErrorPage from './ErrorPage.vue'

describe('ErrorPage', () => {
  it('renders the status, explanation, and home action', () => {
    const wrapper = mount(ErrorPage, {
      props: { code: '404', title: 'Tidak ditemukan', message: 'Halaman tidak tersedia.' },
      global: { stubs: { RouterLink: { template: '<a><slot /></a>' } } },
    })

    expect(wrapper.text()).toContain('404')
    expect(wrapper.text()).toContain('Tidak ditemukan')
    expect(wrapper.text()).toContain('Kembali ke beranda')
    expect(wrapper.find('button').exists()).toBe(false)
  })

  it('emits retry from an application error page', async () => {
    const wrapper = mount(ErrorPage, {
      props: { code: '500', title: 'Error', message: 'Coba lagi.', showRetry: true },
      global: { stubs: { RouterLink: { template: '<a><slot /></a>' } } },
    })

    await wrapper.get('button').trigger('click')
    expect(wrapper.emitted('retry')).toHaveLength(1)
  })
})
