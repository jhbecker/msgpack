#ifndef MSGPACK_AUTO_PTR_HPP__
#define MSGPACK_AUTO_PTR_HPP__

#include <memory>

namespace msgpack {

#if __cplusplus >= 201103L || defined(__GXX_EXPERIMENTAL_CXX0X__)
template<typename T>
class auto_ptr
{
	std::unique_ptr<T> m_ptr;

	public:
	auto_ptr(T* ptr = nullptr) : m_ptr(ptr) {}
	auto_ptr(auto_ptr& other) : m_ptr(std::move(other.m_ptr)) {}
	auto_ptr(auto_ptr&& other) : m_ptr(std::move(other.m_ptr)) {}
	auto_ptr& operator =(auto_ptr& other) { m_ptr = std::move(other.m_ptr); return *this; }
	auto_ptr& operator =(auto_ptr&& other) { m_ptr = std::move(other.m_ptr); return *this; }

	decltype(static_cast<const std::unique_ptr<T>&>(m_ptr).operator->()) operator->() const { return m_ptr.operator->(); }
	decltype(static_cast<const std::unique_ptr<T>&>(m_ptr).operator*()) operator*() const { return m_ptr.operator*(); }
	decltype(m_ptr.release()) release() { return m_ptr.release(); }
	decltype(m_ptr.reset()) reset(T* p=0) { return m_ptr.reset(p); }
	decltype(m_ptr.get()) get() { return m_ptr.get(); }
};
#else
using std::auto_ptr;
#endif

} // namespace msgpack

#endif // MSGPACK_AUTO_PTR_H_
