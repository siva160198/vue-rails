import { createApp } from 'vue'
import './style.css'
import App from './App.vue'
import router from './router'
import { reportAppError } from './services/errorState'
import { initObservability } from './services/observability'
import { useAuth } from './services/auth'
import { installSessionExpirationHandler } from './services/sessionExpirationCoordinator'
import { toast } from './services/toast'
import { t } from './services/i18n'

const app = createApp(App)
initObservability(app, router)
const auth = useAuth()
installSessionExpirationHandler({ router, auth, notify: toast.warning, translate: t })

app.config.errorHandler = (error, instance, info) => {
  console.error('Vue application error:', error, info)
  reportAppError(error)
}

window.addEventListener('unhandledrejection', (event) => {
  console.error('Unhandled promise rejection:', event.reason)
  reportAppError(event.reason)
})

app.use(router).mount('#app')
