// @vitest-environment jsdom
import { act } from 'react'
import { createRoot, type Root } from 'react-dom/client'
import { afterEach, beforeEach, expect, it, vi } from 'vitest'

const mock = vi.hoisted(() => ({ estado: {} as Record<string, unknown>, entrar: vi.fn(), sair: vi.fn(), atualizar: vi.fn() }))
vi.mock('../src/lib/supabase', () => ({ supabase: { auth: { signInWithPassword: mock.entrar, signOut: mock.sair } } }))
vi.mock('../src/hooks/useUsuario', () => ({ useUsuario: () => mock.estado }))
vi.mock('../src/pages/CentralPage', () => ({ default: () => <p>Central disponível</p> }))
import App from '../src/App'

let root: Root
let container: HTMLDivElement
beforeEach(() => {
  Object.assign(globalThis, { IS_REACT_ACT_ENVIRONMENT: true })
  vi.clearAllMocks()
  mock.estado = { usuario: null, inicializando: false, erroAcesso: '', atualizarUsuario: mock.atualizar }
  mock.entrar.mockResolvedValue({ error: null })
  mock.sair.mockResolvedValue({ error: null })
  container = document.createElement('div')
  document.body.appendChild(container)
  root = createRoot(container)
})
afterEach(async () => { await act(async () => { root.unmount() }); container.remove() })
async function render() { await act(async () => { root.render(<App />) }) }
async function preencher(tipo: string, valor: string) {
  const input = container.querySelector<HTMLInputElement>(`input[type="${tipo}"]`)!
  await act(async () => {
    Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value')!.set!.call(input, valor)
    input.dispatchEvent(new Event('input', { bubbles: true }))
  })
}
async function enviar() {
  await act(async () => { container.querySelector('form')!.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true })) })
}
it('limpa a senha após login e carrega o acesso', async () => {
  await render()
  await preencher('email', 'teste@example.com')
  await preencher('password', 'senha-de-teste')
  await enviar()
  expect(mock.entrar).toHaveBeenCalledWith({ email: 'teste@example.com', password: 'senha-de-teste' })
  expect(mock.atualizar).toHaveBeenCalledOnce()
  expect(container.querySelector<HTMLInputElement>('input[type="password"]')!.value).toBe('')
})
it('trata falha de rede sem manter o formulário travado', async () => {
  mock.entrar.mockRejectedValue(new Error('network'))
  await render()
  await preencher('password', 'senha-de-teste')
  await enviar()
  expect(container.querySelector('[role="alert"]')?.textContent).toContain('conexão')
  expect(container.querySelector('button')!.disabled).toBe(false)
  expect(container.querySelector<HTMLInputElement>('input[type="password"]')!.value).toBe('')
})
it('mantém a tela e informa erro quando o logout falha', async () => {
  mock.estado.usuario = { pessoaId: 'p1', empresaId: 'e1', nome: 'Teste', perfil: 'EXECUTOR' }
  mock.sair.mockResolvedValue({ error: new Error('network') })
  await render()
  await act(async () => { container.querySelector<HTMLButtonElement>('.logout-button')!.click() })
  expect(container.textContent).toContain('Central disponível')
  expect(container.querySelector('[role="alert"]')?.textContent).toContain('Não foi possível sair')
  expect(mock.atualizar).not.toHaveBeenCalled()
})
