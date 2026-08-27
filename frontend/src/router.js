import { createRouter, createWebHistory } from 'vue-router'
import HomeView from './views/HomeView.vue'
import LoginView from './views/LoginView.vue'
import ForgotPasswordView from './views/ForgotPasswordView.vue'
import ResetPasswordView from './views/ResetPasswordView.vue'
import RegisterView from './views/RegisterView.vue'
import AdminView from './views/AdminView.vue'
import AdminUsersView from './views/AdminUsersView.vue'
import AdminAuditLogsView from './views/AdminAuditLogsView.vue'
import AdminRolesView from './views/AdminRolesView.vue'
import ForbiddenView from './views/ForbiddenView.vue'
import NotFoundView from './views/NotFoundView.vue'
import AppErrorView from './views/AppErrorView.vue'
import { currentUser } from './services/api'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', component: HomeView },
    { path: '/login', component: LoginView },
    { path: '/forgot-password', component: ForgotPasswordView },
    { path: '/reset-password', component: ResetPasswordView },
    { path: '/register', component: RegisterView },
    { path: '/403', component: ForbiddenView },
    { path: '/error', component: AppErrorView },
    { path: '/admin', component: AdminView, meta: { permission: 'dashboard.view', layout: 'admin' } },
    { path: '/admin/users', component: AdminUsersView, meta: { permission: 'users.view', layout: 'admin' } },
    { path: '/admin/roles', component: AdminRolesView, meta: { permission: 'roles.view', layout: 'admin' } },
    { path: '/admin/audit-logs', component: AdminAuditLogsView, meta: { permission: 'audit_logs.view', layout: 'admin' } },
    { path: '/:pathMatch(.*)*', component: NotFoundView },
  ],
})

router.beforeEach(async (to) => {
  if (!to.meta.permission) return true
  const user = await currentUser()
  if (!user) return { path: '/login', query: { redirect: to.fullPath } }
  if (!user.permissions.includes(to.meta.permission)) return { path: '/403' }
  return true
})

router.onError((error) => {
  console.error('Vue Router error:', error)
  if (router.currentRoute.value.path !== '/error') router.replace('/error')
})

export default router
