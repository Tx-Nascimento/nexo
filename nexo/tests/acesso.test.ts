import { describe, expect, it } from 'vitest'
import { podeAbrirPagina } from '../src/lib/acesso'

describe('acesso às páginas', () => {
  it('nega todas as páginas administrativas para um perfil comum', () => {
    const paginas = ['administracao', 'empresas', 'setores', 'cargos', 'pessoas', 'perfis', 'processos', 'cadastro-operacoes', 'responsabilidades', 'recorrencias'] as const
    for (const pagina of paginas) {
      expect(podeAbrirPagina('EXECUTOR', pagina)).toBe(false)
      expect(podeAbrirPagina('ADMIN', pagina)).toBe(true)
    }
  })
  it('mantém as páginas operacionais disponíveis e não trata DIRETORIA como ADMIN', () => {
    expect(podeAbrirPagina('EXECUTOR', 'operacoes')).toBe(true)
    expect(podeAbrirPagina('DIRETORIA', 'perfis')).toBe(false)
  })
})
