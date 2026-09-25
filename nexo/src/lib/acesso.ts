import type { Pagina } from '../types'

const PAGINAS_ADMIN: ReadonlySet<Pagina> = new Set([
  'administracao', 'empresas', 'setores', 'cargos', 'pessoas', 'perfis',
  'processos', 'cadastro-operacoes', 'responsabilidades', 'recorrencias',
])

// Guarda de interface; a autorização dos dados continua dependendo do RLS.
export function podeAbrirPagina(perfil: string, pagina: Pagina) {
  return !PAGINAS_ADMIN.has(pagina) || perfil === 'ADMIN'
}
