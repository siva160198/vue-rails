import { createApp } from 'vue'
import './style.css'
import App from './App.vue'
import router from './router'
import { reportAppError } from './services/errorState'

const app = createApp(App)

app.config.errorHandler = (error, instance, info) => {
  console.error('Vue application error:', error, info)
  reportAppError(error)
}

window.addEventListener('unhandledrejection', (event) => {
  console.error('Unhandled promise rejection:', event.reason)
  reportAppError(event.reason)
})

app.use(router).mount('#app')
