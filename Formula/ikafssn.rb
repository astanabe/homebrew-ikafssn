class Ikafssn < Formula
  desc "K-mer-based alignment-free similarity search for nucleotide sequences"
  homepage "https://github.com/astanabe/ikafssn"
  url "https://github.com/astanabe/ikafssn/archive/refs/tags/v0.1.2026.02.28.tar.gz"
  sha256 "4eb632492f6430329a4e23875d73c9024f8f9c877d43871e686b7ee58da2b9b8"
  license "Apache-2.0"

  bottle do
    root_url "https://github.com/astanabe/ikafssn/releases/download/v0.1.2026.02.28"
    sha256 cellar: :any, arm64_tahoe: "bcd8b0aa5deaf653dd60e2e70f72449e431288dcb78bc608930321123d3c8a5c"
  end

  depends_on "cmake" => :build
  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libtool" => :build
  depends_on "curl"
  depends_on "drogon"
  depends_on "jsoncpp"
  depends_on "libdeflate"
  depends_on "lmdb"
  depends_on "openssl@3"
  depends_on "sqlite"
  depends_on "tbb"
  depends_on "xz"

  resource "ncbi-cxx-toolkit" do
    url "https://github.com/ncbi/ncbi-cxx-toolkit-public/archive/refs/tags/release/30.0.0.tar.gz"
    sha256 "cde821b44c4f9711b464c56b66b61c5ff419e13b759cc88896154114da6d41a3"
  end

  resource "parasail" do
    url "https://github.com/jeffdaily/parasail/archive/refs/tags/v2.6.2.tar.gz"
    sha256 "9057041db8e1cde76678f649420b85054650414e5de9ea84ee268756c7ea4b4b"
  end

  resource "htslib" do
    url "https://github.com/samtools/htslib/releases/download/1.23/htslib-1.23.tar.bz2"
    sha256 "63927199ef9cea03096345b95d96cb600ae10385248b2ef670b0496c2ab7e4cd"
  end

  def install
    # Build Parasail (static)
    resource("parasail").stage do
      system "cmake", "-S", ".", "-B", "build",
             "-DCMAKE_BUILD_TYPE=Release",
             "-DCMAKE_INSTALL_PREFIX=#{buildpath}/parasail",
             "-DBUILD_SHARED_LIBS=OFF",
             "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
      system "cmake", "--build", "build", "-j#{ENV.make_jobs}"
      system "cmake", "--install", "build"
    end

    # Build htslib (static)
    resource("htslib").stage do
      system "autoreconf", "-i"
      system "./configure",
             "--prefix=#{buildpath}/htslib",
             "--disable-libcurl", "--disable-gcs", "--disable-s3",
             "CPPFLAGS=-I#{HOMEBREW_PREFIX}/include",
             "LDFLAGS=-L#{HOMEBREW_PREFIX}/lib"
      system "make", "-j#{ENV.make_jobs}"
      system "make", "install"
    end

    # Build NCBI C++ Toolkit (static)
    resource("ncbi-cxx-toolkit").stage do
      ENV.prepend "CFLAGS", "-I#{HOMEBREW_PREFIX}/include"
      ENV.prepend "CXXFLAGS", "-I#{HOMEBREW_PREFIX}/include"
      system "./cmake-configure",
             "--without-debug",
             "--with-projects=objtools/blast/seqdb_reader;objtools/blast/blastdb_format",
             "--with-install=#{buildpath}/ncbi-cxx-toolkit"
      cd Dir["CMake-*/build"].first do
        system "make", "-j#{ENV.make_jobs}"
        system "make", "install"
      end
    end

    # Detect NCBI build tag
    ncbi_build_tag = Dir["#{buildpath}/ncbi-cxx-toolkit/CMake-*/"].map { |d| File.basename(d) }.first

    # Build ikafssn
    system "cmake", "-S", ".", "-B", "build",
           "-DCMAKE_BUILD_TYPE=Release",
           "-DNCBI_TOOLKIT_BUILD_TAG=#{ncbi_build_tag}",
           "-DBUILD_HTTPD=ON",
           *std_cmake_args
    system "cmake", "--build", "build", "-j#{ENV.make_jobs}"
    system "cmake", "--install", "build"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/ikafssnindex --version 2>&1")
  end
end
