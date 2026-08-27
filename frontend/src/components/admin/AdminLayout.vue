<script setup>
import { onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import {
  Bell, CalendarDays, ChevronDown, CircleHelp, Compass, LayoutDashboard,
  LogOut, Map, Menu, Moon, PanelLeftClose, PanelLeftOpen, Plane, ScrollText,
  Search, Settings, ShieldCheck, Sun, Users, X,
} from '@lucide/vue'

defineProps({ email: { type: String, default: '' } })
const emit = defineEmits(['logout'])
const route = useRoute()
const sidebarOpen = ref(false)
const desktopSidebarOpen = ref(true)
const profileOpen = ref(false)
const dark = ref(false)
const userManagementOpen = ref(route.path.startsWith('/admin/users') || route.path.startsWith('/admin/roles'))

const navigation = [
  { label: 'Dashboard', icon: LayoutDashboard, to: '/admin' },
  {
    label: 'User Management',
    icon: Users,
    children: [
      { label: 'Users', icon: Users, to: '/admin/users' },
      { label: 'Roles', icon: ShieldCheck, to: '/admin/roles' },
    ],
  },
  { label: 'Audit logs', icon: ScrollText, to: '/admin/audit-logs' },
  { label: 'Trips', icon: Plane },
  { label: 'Destinations', icon: Map },
  { label: 'Bookings', icon: CalendarDays },
]

onMounted(() => {
  dark.value = localStorage.getItem('tourplan-theme') === 'dark'
  desktopSidebarOpen.value = localStorage.getItem('tourplan-sidebar') !== 'closed'
  document.documentElement.classList.toggle('dark', dark.value)
})

function toggleTheme() {
  dark.value = !dark.value
  document.documentElement.classList.toggle('dark', dark.value)
  localStorage.setItem('tourplan-theme', dark.value ? 'dark' : 'light')
}

function toggleDesktopSidebar() {
  desktopSidebarOpen.value = !desktopSidebarOpen.value
  localStorage.setItem('tourplan-sidebar', desktopSidebarOpen.value ? 'open' : 'closed')
}

function toggleUserManagement() {
  const wasCollapsed = !desktopSidebarOpen.value
  if (wasCollapsed) desktopSidebarOpen.value = true
  userManagementOpen.value = wasCollapsed ? true : !userManagementOpen.value
  localStorage.setItem('tourplan-sidebar', 'open')
}
</script>

<template>
  <div class="min-h-screen bg-gray-50 font-outfit dark:bg-gray-900">
    <div v-if="sidebarOpen" class="fixed inset-0 z-40 bg-gray-900/50 lg:hidden" @click="sidebarOpen = false"></div>

    <aside :class="[sidebarOpen ? 'translate-x-0' : '-translate-x-full', desktopSidebarOpen ? 'lg:w-[290px] lg:px-5' : 'lg:w-[90px] lg:px-3']" class="fixed inset-y-0 left-0 z-50 flex w-[290px] flex-col border-r border-gray-200 bg-white px-5 transition-[width,transform,padding] duration-300 dark:border-gray-800 dark:bg-gray-900 lg:translate-x-0">
      <div class="flex h-20 items-center justify-between px-2">
        <RouterLink to="/admin" :class="desktopSidebarOpen ? '' : 'lg:mx-auto'" class="flex items-center gap-3">
          <span class="flex h-10 w-10 items-center justify-center rounded-xl bg-brand-500 text-white"><Compass :size="22" /></span>
          <span :class="desktopSidebarOpen ? '' : 'lg:hidden'"><strong class="block text-xl text-gray-900 dark:text-white">Tourplan</strong><small class="text-gray-400">Admin console</small></span>
        </RouterLink>
        <button class="text-gray-500 lg:hidden" @click="sidebarOpen = false"><X :size="22" /></button>
      </div>

      <nav class="mt-6 flex-1 overflow-y-auto">
        <p :class="desktopSidebarOpen ? '' : 'lg:hidden'" class="mb-4 px-3 text-xs font-medium uppercase tracking-wider text-gray-400">Menu</p>
        <ul class="space-y-2">
          <li v-for="item in navigation" :key="item.label">
            <RouterLink v-if="item.to" :to="item.to" :title="desktopSidebarOpen ? undefined : item.label" :class="[route.path === item.to ? 'bg-brand-50 text-brand-600 dark:bg-brand-500/10 dark:text-brand-400' : 'text-gray-700 hover:bg-gray-100 dark:text-gray-300 dark:hover:bg-white/5', desktopSidebarOpen ? '' : 'lg:justify-center']" class="flex w-full items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium" @click="sidebarOpen = false">
              <component :is="item.icon" :size="20" /><span :class="desktopSidebarOpen ? '' : 'lg:hidden'">{{ item.label }}</span>
            </RouterLink>
            <template v-else-if="item.children">
              <button :title="desktopSidebarOpen ? undefined : item.label" :class="[item.children.some((child) => route.path === child.to) ? 'bg-brand-50 text-brand-600 dark:bg-brand-500/10 dark:text-brand-400' : 'text-gray-700 hover:bg-gray-100 dark:text-gray-300 dark:hover:bg-white/5', desktopSidebarOpen ? '' : 'lg:justify-center']" class="flex w-full items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium" :aria-expanded="userManagementOpen" @click="toggleUserManagement">
                <component :is="item.icon" :size="20" /><span :class="desktopSidebarOpen ? '' : 'lg:hidden'">{{ item.label }}</span><ChevronDown :class="[userManagementOpen ? 'rotate-180' : '', desktopSidebarOpen ? '' : 'lg:hidden']" :size="16" class="ml-auto transition-transform" />
              </button>
              <ul v-show="userManagementOpen" :class="desktopSidebarOpen ? '' : 'lg:hidden'" class="ml-5 mt-2 space-y-1 border-l border-gray-200 pl-4 dark:border-gray-700">
                <li v-for="child in item.children" :key="child.to">
                  <RouterLink :to="child.to" :class="route.path === child.to ? 'bg-brand-50 text-brand-600 dark:bg-brand-500/10 dark:text-brand-400' : 'text-gray-600 hover:bg-gray-100 dark:text-gray-400 dark:hover:bg-white/5'" class="flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium" @click="sidebarOpen = false">
                    <component :is="child.icon" :size="17" />{{ child.label }}
                  </RouterLink>
                </li>
              </ul>
            </template>
            <button v-else :title="desktopSidebarOpen ? undefined : item.label" :class="desktopSidebarOpen ? '' : 'lg:justify-center'" class="flex w-full items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium text-gray-700 hover:bg-gray-100 dark:text-gray-300 dark:hover:bg-white/5">
              <component :is="item.icon" :size="20" /><span :class="desktopSidebarOpen ? '' : 'lg:hidden'">{{ item.label }}</span><span :class="desktopSidebarOpen ? '' : 'lg:hidden'" class="ml-auto rounded-full bg-gray-100 px-2 py-0.5 text-[10px] text-gray-500 dark:bg-gray-800">Soon</span>
            </button>
          </li>
        </ul>
        <p :class="desktopSidebarOpen ? '' : 'lg:hidden'" class="mb-4 mt-8 px-3 text-xs font-medium uppercase tracking-wider text-gray-400">Support</p>
        <ul class="space-y-2">
          <li><button title="Settings" :class="desktopSidebarOpen ? '' : 'lg:justify-center'" class="flex w-full items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium text-gray-700 hover:bg-gray-100 dark:text-gray-300 dark:hover:bg-white/5"><Settings :size="20" /><span :class="desktopSidebarOpen ? '' : 'lg:hidden'">Settings</span></button></li>
          <li><button title="Help center" :class="desktopSidebarOpen ? '' : 'lg:justify-center'" class="flex w-full items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium text-gray-700 hover:bg-gray-100 dark:text-gray-300 dark:hover:bg-white/5"><CircleHelp :size="20" /><span :class="desktopSidebarOpen ? '' : 'lg:hidden'">Help center</span></button></li>
        </ul>
      </nav>

      <div :class="desktopSidebarOpen ? 'p-4' : 'lg:flex lg:justify-center lg:p-3'" class="mb-6 rounded-2xl bg-gray-50 dark:bg-white/5">
        <div :class="desktopSidebarOpen ? '' : 'lg:hidden'"><p class="text-sm font-semibold text-gray-900 dark:text-white">Tourplan API</p><div class="mt-2 flex items-center gap-2 text-xs text-gray-500"><span class="h-2 w-2 rounded-full bg-success-500"></span>All systems operational</div></div>
        <span v-if="!desktopSidebarOpen" class="hidden h-3 w-3 rounded-full bg-success-500 ring-4 ring-success-50 dark:ring-success-500/10 lg:block" title="All systems operational"></span>
      </div>
    </aside>

    <div :class="desktopSidebarOpen ? 'lg:pl-[290px]' : 'lg:pl-[90px]'" class="transition-[padding] duration-300">
      <header class="sticky top-0 z-30 flex h-20 items-center justify-between border-b border-gray-200 bg-white px-4 dark:border-gray-800 dark:bg-gray-900 sm:px-6">
        <div class="flex items-center gap-3">
          <button class="flex h-10 w-10 items-center justify-center rounded-lg border border-gray-200 text-gray-500 dark:border-gray-800 lg:hidden" @click="sidebarOpen = true"><Menu :size="20" /></button>
          <button :aria-label="desktopSidebarOpen ? 'Kecilkan sidebar' : 'Lebarkan sidebar'" :title="desktopSidebarOpen ? 'Kecilkan sidebar' : 'Lebarkan sidebar'" class="hidden h-10 w-10 items-center justify-center rounded-lg border border-gray-200 text-gray-500 hover:bg-gray-100 dark:border-gray-800 dark:hover:bg-gray-800 lg:flex" @click="toggleDesktopSidebar">
            <PanelLeftClose v-if="desktopSidebarOpen" :size="20" />
            <PanelLeftOpen v-else :size="20" />
          </button>
          <div class="relative hidden md:block">
            <Search :size="18" class="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
            <input class="w-72 rounded-lg border border-gray-200 bg-transparent py-2.5 pl-10 pr-4 text-sm outline-none focus:border-brand-400 dark:border-gray-800 dark:text-white" placeholder="Search or type command..." />
          </div>
        </div>
        <div class="flex items-center gap-3">
          <button class="flex h-10 w-10 items-center justify-center rounded-full border border-gray-200 text-gray-500 hover:bg-gray-100 dark:border-gray-800 dark:hover:bg-gray-800" @click="toggleTheme"><Sun v-if="dark" :size="19" /><Moon v-else :size="19" /></button>
          <button class="relative flex h-10 w-10 items-center justify-center rounded-full border border-gray-200 text-gray-500 hover:bg-gray-100 dark:border-gray-800 dark:hover:bg-gray-800"><Bell :size="19" /><span class="absolute right-0 top-0 h-2.5 w-2.5 rounded-full border-2 border-white bg-orange-500 dark:border-gray-900"></span></button>
          <div class="relative">
            <button class="flex items-center gap-3" @click="profileOpen = !profileOpen">
              <span class="flex h-10 w-10 items-center justify-center rounded-full bg-brand-100 font-semibold text-brand-600 dark:bg-brand-500/15 dark:text-brand-400">A</span>
              <span class="hidden text-left md:block"><strong class="block max-w-40 truncate text-sm text-gray-700 dark:text-gray-200">Administrator</strong><small class="text-gray-400">{{ email }}</small></span>
              <ChevronDown :size="16" class="hidden text-gray-400 md:block" />
            </button>
            <div v-if="profileOpen" class="absolute right-0 mt-3 w-64 rounded-xl border border-gray-200 bg-white p-3 shadow-theme-lg dark:border-gray-800 dark:bg-gray-900">
              <div class="border-b border-gray-100 px-2 pb-3 dark:border-gray-800"><p class="text-sm font-medium dark:text-white">Administrator</p><p class="mt-1 truncate text-xs text-gray-500">{{ email }}</p></div>
              <button class="mt-2 flex w-full items-center gap-2 rounded-lg px-2 py-2 text-sm text-gray-600 hover:bg-gray-50 dark:text-gray-300 dark:hover:bg-gray-800" @click="emit('logout')"><LogOut :size="18" />Sign out</button>
            </div>
          </div>
        </div>
      </header>
      <main class="p-4 sm:p-6"><slot /></main>
    </div>
  </div>
</template>
