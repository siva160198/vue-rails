import { createRouter, createWebHistory } from 'vue-router'
import HomeView from './views/HomeView.vue'
import LoginView from './views/LoginView.vue'
import ForgotPasswordView from './views/ForgotPasswordView.vue'
import RegisterView from './views/RegisterView.vue'
import AdminView from './views/AdminView.vue'
import { currentUser } from './services/api'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', component: HomeView },
    { path: '/login', component: LoginView },
    { path: '/forgot-password', component: ForgotPasswordView },
    { path: '/register', component: RegisterView },
    { path: '/admin', component: AdminView, meta: { requiresAdmin: true, layout: 'admin' } },
  ],
})

router.beforeEach(async (to) => {
  if (!to.meta.requiresAdmin) return true
  const user = await currentUser()
  if (!user) return { path: '/login', query: { redirect: to.fullPath } }
  if (user.role !== 'admin') return { path: '/' }
  return true
})

export default router
