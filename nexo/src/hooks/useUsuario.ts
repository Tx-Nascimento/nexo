import { useCallback, useEffect, useRef, useState } from 'react'
import { supabase } from '../lib/supabase'
import { buscarUsuarioAtual } from '../services/nexoService'
import type { DadosUsuario } from '../types'

export function useUsuario() {
  const [usuario, setUsuario] = useState<DadosUsuario | null>(null)
  const [inicializando, setInicializando] = useState(true)
  const [erroAcesso, setErroAcesso] = useState('')
  const versao = useRef(0)
  const montado = useRef(false)

  const atualizarUsuario = useCallback(async () => {
    const atual = ++versao.current
    try {
      const dados = await buscarUsuarioAtual()
      if (!montado.current || atual !== versao.current) return
      setUsuario(dados)
      setErroAcesso('')
    } catch (error) {
      if (!montado.current || atual !== versao.current) return
      // Nunca conservar um perfil antigo após falha na validação do acesso.
      setUsuario(null)
      setErroAcesso(error instanceof Error ? error.message : 'Não foi possível validar seu acesso. Tente novamente.')
    } finally {
      if (montado.current && atual === versao.current) setInicializando(false)
    }
  }, [])

  useEffect(() => {
    montado.current = true
    const controle = versao
    let agendado: ReturnType<typeof setTimeout> | undefined
    let identidade: string | undefined

    const { data: { subscription } } = supabase.auth.onAuthStateChange((evento, sessao) => {
      // Invalida respostas anteriores imediatamente, inclusive logout em outra aba.
      ++versao.current
      clearTimeout(agendado)
      if (!sessao || evento === 'SIGNED_OUT') {
        identidade = undefined
        setUsuario(null)
        setErroAcesso('')
        setInicializando(false)
        return
      }
      if (identidade !== sessao.user.id) {
        identidade = sessao.user.id
        setUsuario(null)
      }
      // Não chamar métodos Auth dentro do callback: o SDK pode manter seu lock.
      agendado = setTimeout(() => { void atualizarUsuario() }, 0)
    })

    const revalidar = () => {
      if (document.visibilityState === 'visible') void atualizarUsuario()
    }
    agendado = setTimeout(() => { void atualizarUsuario() }, 0)
    window.addEventListener('focus', revalidar)
    window.addEventListener('online', revalidar)
    document.addEventListener('visibilitychange', revalidar)

    return () => {
      montado.current = false
      ++controle.current
      clearTimeout(agendado)
      subscription.unsubscribe()
      window.removeEventListener('focus', revalidar)
      window.removeEventListener('online', revalidar)
      document.removeEventListener('visibilitychange', revalidar)
    }
  }, [atualizarUsuario])

  return { usuario, inicializando, erroAcesso, atualizarUsuario }
}
